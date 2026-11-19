variable "organization_id" {
  description = "AWS Organizations ID used in role trust conditions."
  type        = string
}

variable "management_account_id" {
  description = "AWS Organizations management account ID."
  type        = string
}

variable "security_account_id" {
  description = "Delegated Security account ID."
  type        = string
}

variable "workload_account_id" {
  description = "Single workload account ID managed by this project root."
  type        = string
}

variable "management_operator_role_arn" {
  description = "Exact IAM role ARN in the Management account permitted to enter the Security audit role."
  type        = string
}
