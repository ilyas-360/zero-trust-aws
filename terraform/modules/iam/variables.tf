variable "organization_id" {
  description = "AWS Organizations ID — used in trust policy conditions"
  type        = string
}

variable "management_account" {
  description = "Management account ID"
  type        = string
}

variable "security_account" {
  description = "Security account ID"
  type        = string
}

variable "workload_accounts" {
  description = "List of workload account IDs"
  type        = list(string)
}
