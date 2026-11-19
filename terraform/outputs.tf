output "organization_id" {
  description = "AWS Organizations identifier."
  value       = module.organizations.organization_id
}

output "transit_gateway_id" {
  description = "Transit Gateway in the Network account."
  value       = module.networking.transit_gateway_id
}

output "workload_vpc_id" {
  description = "VPC created in the configured workload account."
  value       = module.networking.workload_vpc_id
}

output "cloudtrail_bucket_arn" {
  description = "Organization CloudTrail destination bucket in the Logging account."
  value       = module.logging.cloudtrail_bucket_arn
}

output "organization_trail_arn" {
  description = "Organization CloudTrail ARN created from the Management account."
  value       = module.logging.organization_trail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector in the delegated Security account; null when GuardDuty is disabled."
  value       = module.security.guardduty_detector_id
}

output "securityhub_arn" {
  description = "Security Hub ARN in the delegated Security account; null when Security Hub is disabled."
  value       = module.security.securityhub_arn
}
