resource "aws_sns_topic" "resized" {
  name = "${var.project_name}-notifications"
}

# The recipient must click "Confirm subscription" in the first email AWS sends.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.resized.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
