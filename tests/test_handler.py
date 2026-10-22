import importlib
import io
import os
import sys
from unittest.mock import MagicMock

import boto3
import pytest
from moto import mock_aws
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

SRC, DST = "source-bucket", "dest-bucket"


@pytest.fixture
def lambda_module(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "test")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "test")
    monkeypatch.setenv("S3_Bucket", DST)
    monkeypatch.setenv("Topic_Arn", "arn:aws:sns:us-east-1:123456789012:topic")
    monkeypatch.setenv("MAX_WIDTH", "100")
    monkeypatch.setenv("MAX_HEIGHT", "100")
    with mock_aws():
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=SRC)
        s3.create_bucket(Bucket=DST)
        import create_thumbnail

        mod = importlib.reload(create_thumbnail)
        mod.sns = MagicMock()
        yield mod, s3


def _put_image(s3, key, size=(800, 400), fmt="JPEG", mode="RGB"):
    buf = io.BytesIO()
    Image.new(mode, size, "red").save(buf, format=fmt)
    s3.put_object(Bucket=SRC, Key=key, Body=buf.getvalue())


def _event(key):
    return {"Records": [{"s3": {"bucket": {"name": SRC}, "object": {"key": key}}}]}


def _dest_image(s3, key):
    body = s3.get_object(Bucket=DST, Key=key)["Body"].read()
    return Image.open(io.BytesIO(body))


def test_resizes_and_keeps_aspect_ratio(lambda_module):
    mod, s3 = lambda_module
    _put_image(s3, "photo.jpg")
    mod.handler(_event("photo.jpg"), None)
    img = _dest_image(s3, "photo.jpg")
    assert img.size == (100, 50)
    assert mod.sns.publish.call_args.kwargs["Subject"] == "Image resized"


def test_key_with_spaces_and_folders(lambda_module):
    mod, s3 = lambda_module
    _put_image(s3, "my folder/my photo.png", fmt="PNG")
    mod.handler(_event("my+folder/my+photo.png"), None)
    assert _dest_image(s3, "my folder/my photo.png").format == "PNG"


def test_small_image_is_not_upscaled(lambda_module):
    mod, s3 = lambda_module
    _put_image(s3, "small.jpg", size=(40, 20))
    mod.handler(_event("small.jpg"), None)
    assert _dest_image(s3, "small.jpg").size == (40, 20)


def test_unsupported_file_is_skipped(lambda_module):
    mod, s3 = lambda_module
    s3.put_object(Bucket=SRC, Key="notes.txt", Body=b"hello")
    mod.handler(_event("notes.txt"), None)
    mod.sns.publish.assert_not_called()
    assert "Contents" not in s3.list_objects_v2(Bucket=DST)


def test_corrupt_image_sends_failure_notice(lambda_module):
    mod, s3 = lambda_module
    s3.put_object(Bucket=SRC, Key="bad.jpg", Body=b"not an image")
    mod.handler(_event("bad.jpg"), None)
    assert mod.sns.publish.call_args.kwargs["Subject"] == "Image resize FAILED"
    assert "Contents" not in s3.list_objects_v2(Bucket=DST)
