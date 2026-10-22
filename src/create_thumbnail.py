"""Lambda: resize images uploaded to the source S3 bucket.

Trigger : S3 ObjectCreated event on the source bucket
Output  : resized image written to the destination bucket (same key)
Notify  : SNS email on success and on failure

Environment variables
---------------------
S3_Bucket   destination bucket name (required)
Topic_Arn   SNS topic ARN (required)
MAX_WIDTH   max thumbnail width  in px (default 300)
MAX_HEIGHT  max thumbnail height in px (default 300)
"""
import logging
import mimetypes
import os
import uuid
from urllib.parse import unquote_plus

import boto3
from botocore.config import Config
from PIL import Image, ImageOps

log = logging.getLogger()
log.setLevel(logging.INFO)

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
PRESIGNED_URL_SECONDS = 3600

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))
sns = boto3.client("sns")


def _max_size():
    return (
        int(os.environ.get("MAX_WIDTH", "300")),
        int(os.environ.get("MAX_HEIGHT", "300")),
    )


def resize_image(src_path, dst_path, max_size):
    """Shrink the image to fit inside max_size, keeping aspect ratio.

    Returns ((orig_w, orig_h), (new_w, new_h)).
    """
    with Image.open(src_path) as img:
        original_size = img.size
        fmt = img.format  # remember it: exif_transpose() returns a copy without it
        img = ImageOps.exif_transpose(img)  # fix phone-photo rotation
        img.thumbnail(max_size)  # in place, keeps aspect ratio, never upscales
        if fmt == "JPEG" and img.mode not in ("RGB", "L"):
            img = img.convert("RGB")
        img.save(dst_path, format=fmt)
        return original_size, img.size


def _notify(subject, message):
    sns.publish(
        TopicArn=os.environ["Topic_Arn"],
        Subject=subject[:100],  # SNS subject limit
        Message=message,
    )


def _process_record(record, dest_bucket, max_size):
    bucket = record["s3"]["bucket"]["name"]
    key = unquote_plus(record["s3"]["object"]["key"])  # "my+photo.jpg" -> "my photo.jpg"
    ext = os.path.splitext(key)[1].lower()

    if ext not in SUPPORTED_EXTENSIONS:
        log.info("Skipping unsupported file: s3://%s/%s", bucket, key)
        return

    name = os.path.basename(key)  # keys may contain "/" folders
    src_path = f"/tmp/{uuid.uuid4()}-{name}"
    dst_path = f"/tmp/resized-{uuid.uuid4()}-{name}"

    try:
        s3.download_file(bucket, key, src_path)
        original, resized = resize_image(src_path, dst_path, max_size)

        content_type = mimetypes.guess_type(name)[0] or "application/octet-stream"
        s3.upload_file(
            dst_path, dest_bucket, key, ExtraArgs={"ContentType": content_type}
        )

        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": dest_bucket, "Key": key},
            ExpiresIn=PRESIGNED_URL_SECONDS,
        )
        message = (
            f"Image resized successfully.\n\n"
            f"Original : s3://{bucket}/{key} ({original[0]}x{original[1]})\n"
            f"Resized  : s3://{dest_bucket}/{key} ({resized[0]}x{resized[1]})\n\n"
            f"Download link (valid {PRESIGNED_URL_SECONDS // 60} minutes):\n{url}\n"
        )
        log.info("Resized s3://%s/%s -> s3://%s/%s", bucket, key, dest_bucket, key)
        _notify("Image resized", message)
    except Exception:
        log.exception("Failed to resize s3://%s/%s", bucket, key)
        _notify("Image resize FAILED", f"Could not resize s3://{bucket}/{key}. See CloudWatch logs.")
    finally:
        for path in (src_path, dst_path):
            if os.path.exists(path):
                os.remove(path)


def handler(event, context):
    dest_bucket = os.environ["S3_Bucket"]
    max_size = _max_size()
    for record in event.get("Records", []):
        _process_record(record, dest_bucket, max_size)
    return {"status": "done"}
