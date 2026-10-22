data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# CloudWatch Logs permissions (AWS managed policy)
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: read source, write/read resized, publish to our topic only.
data "aws_iam_policy_document" "lambda_access" {
  statement {
    sid       = "ReadSourceImages"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    sid       = "WriteResizedImages"
    actions   = ["s3:PutObject", "s3:GetObject"] # GetObject is needed to sign the download link
    resources = ["${aws_s3_bucket.resized.arn}/*"]
  }

  statement {
    sid       = "PublishNotifications"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.resized.arn]
  }
}

resource "aws_iam_role_policy" "lambda_access" {
  name   = "${var.project_name}-lambda-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_access.json
}
