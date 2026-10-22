data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  source_bucket  = "${var.source_bucket_prefix}-${local.account_id}"
  resized_bucket = "${var.resized_bucket_prefix}-${local.account_id}"
  function_name  = "${var.project_name}-lambda"
  lambda_runtime = "python3.12"
}
