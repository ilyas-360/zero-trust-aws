variable "security_account_id" {
  description = "Delegated Security account ID."
  type        = string
}

variable "aws_region" {
  description = "Region in which GuardDuty and Security Hub resources are managed."
  type        = string
}

variable "enable_guardduty" {
  description = "Whether to delegate and enable GuardDuty for the organization."
  type        = bool
}

variable "enable_securityhub" {
  description = "Whether to delegate and enable Security Hub for the organization."
  type        = bool
}

variable "alert_email_address" {
  description = "Optional email endpoint for high-severity GuardDuty alerts."
  type        = string
  default     = null
  nullable    = true
}
