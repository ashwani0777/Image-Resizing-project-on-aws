variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to name resources"
  type        = string
  default     = "image-resizer"
}

variable "notification_email" {
  description = "Email address that receives resize notifications (must confirm the SNS subscription)"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "source_bucket_prefix" {
  description = "Prefix for the upload bucket; the AWS account ID is appended to keep it globally unique"
  type        = string
  default     = "image-source"
}

variable "resized_bucket_prefix" {
  description = "Prefix for the resized-images bucket; the AWS account ID is appended"
  type        = string
  default     = "image-resized"
}

variable "allowed_extensions" {
  description = "File extensions (case-sensitive, with dot) that trigger the Lambda"
  type        = list(string)
  default     = [".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG", ".WEBP"]
}

variable "max_width" {
  description = "Maximum thumbnail width in pixels"
  type        = number
  default     = 300
}

variable "max_height" {
  description = "Maximum thumbnail height in pixels"
  type        = number
  default     = 300
}

variable "lambda_memory_mb" {
  type    = number
  default = 512
}

variable "lambda_timeout_seconds" {
  type    = number
  default = 60
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the Lambda logs"
  type        = number
  default     = 14
}

variable "force_destroy_buckets" {
  description = "Allow `terraform destroy` to delete buckets that still contain images (good for a demo, turn off for real data)"
  type        = bool
  default     = true
}
