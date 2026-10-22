locals {
  buckets = {
    source  = aws_s3_bucket.source.id
    resized = aws_s3_bucket.resized.id
  }
}

resource "aws_s3_bucket" "source" {
  bucket        = local.source_bucket
  force_destroy = var.force_destroy_buckets
}

resource "aws_s3_bucket" "resized" {
  bucket        = local.resized_bucket
  force_destroy = var.force_destroy_buckets
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
