output "guardduty_detector_id" {
  description = "Security-account GuardDuty detector ID, or null when GuardDuty is disabled."
  value       = try(aws_guardduty_detector.security[0].id, null)
}

output "securityhub_arn" {
  description = "Security Hub ARN, or null when Security Hub is disabled."
  value       = try(aws_securityhub_account.security[0].arn, null)
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN, or null when GuardDuty alerting is disabled."
  value       = try(aws_sns_topic.security_alerts[0].arn, null)
}
