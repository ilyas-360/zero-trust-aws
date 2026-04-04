# =============================================================================
# Outputs — values exposed after terraform apply
# =============================================================================

output "organization_id" {
  description = "AWS Organizations ID"
  value       = module.organizations.organization_id
  sensitive   = false
}

output "transit_gateway_id" {
  description = "Transit Gateway ID in the Network account"
  value       = module.networking.transit_gateway_id
  sensitive   = false
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket ARN for immutable CloudTrail logs"
  value       = module.logging.cloudtrail_bucket_arn
  sensitive   = false
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the Security account"
  value       = module.security.guardduty_detector_id
  sensitive   = false
}

output "security_hub_arn" {
  description = "Security Hub ARN in the Security account"
  value       = module.security.security_hub_arn
  sensitive   = false
}
