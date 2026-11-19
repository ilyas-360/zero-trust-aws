variable "allowed_regions" {
  description = "AWS Regions allowed by the Organizations SCP."
  type        = list(string)
}

variable "member_account_ids" {
  description = "Existing member accounts that receive guardrails directly in addition to inheriting OU guardrails."
  type        = list(string)
}
