variable "organization_name" {
  description = "Name tag for the organization"
  type        = string
}

variable "allowed_regions" {
  description = "AWS regions permitted by SCP"
  type        = list(string)
}
