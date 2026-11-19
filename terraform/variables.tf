variable "aws_region" {
  description = "Primary AWS Region for the lab. Must be present in the allowed_regions SCP input."
  type        = string
  default     = "eu-west-1"
}

variable "management_profile" {
  description = "AWS CLI profile authenticated to the AWS Organizations management account (prefer IAM Identity Center)."
  type        = string
  default     = "management"
}

variable "security_profile" {
  description = "AWS CLI profile authenticated to the delegated Security account."
  type        = string
  default     = "security"
}

variable "logging_profile" {
  description = "AWS CLI profile authenticated to the Logging account."
  type        = string
  default     = "logging"
}

variable "network_profile" {
  description = "AWS CLI profile authenticated to the Network account."
  type        = string
  default     = "network"
}

variable "workload_profile" {
  description = "AWS CLI profile authenticated to the workload account."
  type        = string
  default     = "workload"
}

variable "management_account_id" {
  description = "12-digit AWS Organizations management account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must contain exactly 12 digits."
  }
}

variable "security_account_id" {
  description = "12-digit delegated Security account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "security_account_id must contain exactly 12 digits."
  }
}

variable "logging_account_id" {
  description = "12-digit Logging account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.logging_account_id))
    error_message = "logging_account_id must contain exactly 12 digits."
  }
}

variable "network_account_id" {
  description = "12-digit Network account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.network_account_id))
    error_message = "network_account_id must contain exactly 12 digits."
  }
}

variable "workload_account_id" {
  description = "12-digit workload account ID. This root configuration manages one workload account/VPC."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.workload_account_id))
    error_message = "workload_account_id must contain exactly 12 digits."
  }
}

variable "management_operator_role_arn" {
  description = "Exact IAM Identity Center or IAM role ARN in the Management account allowed to assume the Security audit role."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.management_operator_role_arn))
    error_message = "management_operator_role_arn must be an IAM role ARN in the commercial AWS partition."
  }
}


variable "allowed_regions" {
  description = "AWS Regions permitted by the SCP. Include aws_region."
  type        = list(string)
  default     = ["eu-west-1"]

  validation {
    condition     = length(var.allowed_regions) > 0
    error_message = "allowed_regions must contain at least one Region. Include aws_region."
  }
}

variable "network_vpc_cidr" {
  description = "CIDR for the Network account egress VPC. Must not overlap the workload VPC or external networks."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.network_vpc_cidr))
    error_message = "network_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "workload_vpc_cidr" {
  description = "CIDR for the single workload VPC. Must not overlap the Network VPC or external networks."
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.workload_vpc_cidr))
    error_message = "workload_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "workload_subnet_cidrs" {
  description = "Two private workload subnet CIDRs in distinct Availability Zones."
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24"]

  validation {
    condition     = length(var.workload_subnet_cidrs) == 2 && alltrue([for cidr in var.workload_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Provide exactly two valid IPv4 workload subnet CIDRs."
  }
}

variable "cloudtrail_bucket_name" {
  description = "Globally unique bucket name for organization CloudTrail logs; choose a name with a random suffix."
  type        = string

  validation {
    condition     = length(var.cloudtrail_bucket_name) >= 3 && length(var.cloudtrail_bucket_name) <= 63 && startswith(var.cloudtrail_bucket_name, "zero-trust-cloudtrail-logs-") && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.cloudtrail_bucket_name)) && !strcontains(var.cloudtrail_bucket_name, "..")
    error_message = "Use a globally unique 3–63 character S3 bucket name beginning with zero-trust-cloudtrail-logs- and containing only lowercase letters, numbers, dots, or hyphens."
  }
}

variable "flow_log_retention_days" {
  description = "CloudWatch log retention in days for VPC Flow Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a CloudWatch Logs supported retention period."
  }
}

variable "s3_data_event_arns" {
  description = "Optional, explicit S3 object ARNs to include in CloudTrail data-event logging. Empty disables S3 data events to avoid noisy, billable all-bucket logging."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create a billable NAT Gateway for controlled workload egress. Disabled by default for cost control."
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty in the delegated Security account and for the organization. GuardDuty usage is billable."
  type        = bool
  default     = false
}

variable "enable_securityhub" {
  description = "Enable Security Hub CSPM and standards. Security Hub usage is billable."
  type        = bool
  default     = false
}

variable "vpn_customer_gateway" {
  description = "Optional external IPsec customer gateway. When set, the module creates an AWS Site-to-Site VPN and expects the endpoint to be configured with AWS's downloaded tunnel configuration."
  type = object({
    public_ip  = string
    bgp_asn    = number
    onprem_cidr = string
  })
  default  = null
  nullable = true

  validation {
    condition = var.vpn_customer_gateway == null ? true : (
      can(cidrhost("${var.vpn_customer_gateway.public_ip}/32", 0)) &&
      can(cidrnetmask(var.vpn_customer_gateway.onprem_cidr)) &&
      var.vpn_customer_gateway.bgp_asn >= 1 &&
      var.vpn_customer_gateway.bgp_asn <= 4294967294
    )
    error_message = "When enabled, vpn_customer_gateway requires a valid IPv4 public IP, valid on-premises IPv4 CIDR, and a BGP ASN from 1 to 4294967294."
  }
}

variable "alert_email_address" {
  description = "Optional SNS email endpoint for high-severity GuardDuty findings. Confirm the subscription in the email inbox."
  type        = string
  default     = null
  nullable    = true
}
