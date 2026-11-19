variable "management_account_id" {
  description = "AWS Organizations management account ID."
  type        = string
}

variable "logging_account_id" {
  description = "Logging member account ID."
  type        = string
}

variable "organization_id" {
  description = "AWS Organizations ID used to scope the CloudTrail bucket write path."
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "Globally unique bucket name, prefixed with zero-trust-cloudtrail-logs-."
  type        = string
}

variable "s3_data_event_arns" {
  description = "Optional S3 object ARNs for CloudTrail data events. Empty disables data events."
  type        = list(string)
  default     = []
}
