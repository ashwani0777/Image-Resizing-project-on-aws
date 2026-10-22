# Package the function code straight from src/ (no manual zipping).
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/create_thumbnail.py"
  output_path = "${path.module}/build/create_thumbnail.zip"
}

# Pillow layer built for Python 3.12 / x86_64 (see scripts/build_layer.sh to rebuild).
resource "aws_lambda_layer_version" "pillow" {
  layer_name               = "${var.project_name}-pillow"
  filename                 = "${path.module}/layer/pillow-layer.zip"
  source_code_hash         = filebase64sha256("${path.module}/layer/pillow-layer.zip")
  compatible_runtimes      = [local.lambda_runtime]
  compatible_architectures = ["x86_64"]
}

# Created explicitly so logs expire instead of piling up forever.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "resize" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  runtime       = local.lambda_runtime
  architectures = ["x86_64"]
  handler       = "create_thumbnail.handler"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  layers           = [aws_lambda_layer_version.pillow.arn]

  environment {
    variables = {
      Topic_Arn  = aws_sns_topic.resized.arn
      S3_Bucket  = aws_s3_bucket.resized.id
      MAX_WIDTH  = tostring(var.max_width)
      MAX_HEIGHT = tostring(var.max_height)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.logs,
    aws_iam_role_policy.lambda_access,
  ]
}

# Allow only OUR source bucket (in OUR account) to invoke the function.
resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.resize.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.source.arn
  source_account = local.account_id
}

# Only image files trigger the function (one filter per extension).
resource "aws_s3_bucket_notification" "source" {
  bucket = aws_s3_bucket.source.id

  dynamic "lambda_function" {
    for_each = toset(var.allowed_extensions)

    content {
      lambda_function_arn = aws_lambda_function.resize.arn
      events              = ["s3:ObjectCreated:*"]
      filter_suffix       = lambda_function.value
    }
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
