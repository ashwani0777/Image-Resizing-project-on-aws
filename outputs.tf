output "source_bucket" {
  description = "Upload your original images here"
  value       = aws_s3_bucket.source.id
}

output "resized_bucket" {
  description = "Resized images appear here"
  value       = aws_s3_bucket.resized.id
}

output "lambda_function_name" {
  value = aws_lambda_function.resize.function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.resized.arn
}

output "test_upload_command" {
  description = "Copy-paste to test the pipeline"
  value       = "aws s3 cp ./photo.jpg s3://${aws_s3_bucket.source.id}/photo.jpg"
}

output "tail_logs_command" {
  value = "aws logs tail /aws/lambda/${aws_lambda_function.resize.function_name} --follow"
}
