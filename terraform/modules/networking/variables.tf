variable "organization_arn" {
  description = "AWS Organizations ARN used as the AWS RAM share principal."
  type        = string
}

variable "aws_region" {
  description = "AWS Region for VPC, Transit Gateway, Flow Logs, and optional VPN resources."
  type        = string
}

variable "network_account_id" {
  description = "Network member account ID."
  type        = string
}

variable "workload_account_id" {
  description = "Single workload member account ID."
  type        = string
}

variable "network_vpc_cidr" {
  description = "Non-overlapping CIDR for the Network account egress VPC."
  type        = string
}

variable "workload_vpc_cidr" {
  description = "Non-overlapping CIDR for the workload VPC."
  type        = string
}

variable "workload_subnet_cidrs" {
  description = "Two non-overlapping private subnet CIDRs within workload_vpc_cidr."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway and default egress routes."
  type        = bool
}

variable "flow_log_retention_days" {
  description = "CloudWatch log retention for VPC Flow Logs."
  type        = number
}

variable "customer_gateway_public_ip" {
  description = "Optional public IP address of an external IPsec customer gateway. Leave null to omit the VPN."
  type        = string
  default     = null
  nullable    = true
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN configured on the customer gateway when the optional VPN is enabled."
  type        = number
  default     = 65000
}

variable "onprem_cidr" {
  description = "Optional on-premises CIDR advertised through VPN. Required with customer_gateway_public_ip."
  type        = string
  default     = null
  nullable    = true
}
