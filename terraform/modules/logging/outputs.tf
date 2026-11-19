output "cloudtrail_bucket_arn" {
  description = "S3 bucket ARN in the Logging account."
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "organization_trail_arn" {
  description = "Organization CloudTrail ARN in the Management account."
  value       = aws_cloudtrail.organization.arn
}
