# =============================================================================
# Input Variables — Zero Trust AWS Architecture
# =============================================================================

variable "aws_region" {
  description = "Primary AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "organization_name" {
  description = "Name of the AWS Organization"
  type        = string
}

variable "allowed_regions" {
  description = "List of AWS regions permitted by SCP. All other regions are denied."
  type        = list(string)
  default     = ["eu-west-1", "eu-west-3"]
}

# -----------------------------------------------------------------------------
# Account IDs — set in terraform.tfvars (never commit real values)
# -----------------------------------------------------------------------------

variable "management_account_id" {
  description = "AWS Account ID for the Management account"
  type        = string
  sensitive   = true
}

variable "security_account_id" {
  description = "AWS Account ID for the Security account (GuardDuty + Security Hub)"
  type        = string
  sensitive   = true
}

variable "logging_account_id" {
  description = "AWS Account ID for the Logging account (immutable CloudTrail)"
  type        = string
  sensitive   = true
}

variable "network_account_id" {
  description = "AWS Account ID for the Network account (Transit Gateway)"
  type        = string
  sensitive   = true
}

variable "workload_account_ids" {
  description = "List of workload account IDs — permission boundaries applied to all"
  type        = list(string)
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vpc_cidr_management" {
  description = "CIDR block for the Management account VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_security" {
  description = "CIDR block for the Security account VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "vpc_cidr_workload" {
  description = "CIDR block for the Workload account VPC"
  type        = string
  default     = "10.2.0.0/16"
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

