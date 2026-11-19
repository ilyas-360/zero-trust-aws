terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "organizations" {
  source = "./modules/organizations"

  providers = {
    aws.management = aws.management
  }

  allowed_regions = var.allowed_regions
  member_account_ids = [
    var.security_account_id,
    var.logging_account_id,
    var.network_account_id,
    var.workload_account_id,
  ]
}

module "iam" {
  source = "./modules/iam"

  providers = {
    aws.security = aws.security
    aws.workload = aws.workload
  }

  organization_id              = module.organizations.organization_id
  management_account_id        = var.management_account_id
  security_account_id          = var.security_account_id
  workload_account_id          = var.workload_account_id
  management_operator_role_arn = var.management_operator_role_arn
}

module "networking" {
  source = "./modules/networking"

  providers = {
    aws.management = aws.management
    aws.network    = aws.network
    aws.workload   = aws.workload
  }

  organization_arn           = module.organizations.organization_arn
  aws_region                 = var.aws_region
  network_account_id         = var.network_account_id
  workload_account_id        = var.workload_account_id
  network_vpc_cidr           = var.network_vpc_cidr
  workload_vpc_cidr          = var.workload_vpc_cidr
  workload_subnet_cidrs      = var.workload_subnet_cidrs
  enable_nat_gateway         = var.enable_nat_gateway
  flow_log_retention_days    = var.flow_log_retention_days
  customer_gateway_public_ip = try(var.vpn_customer_gateway.public_ip, null)
  customer_gateway_bgp_asn   = try(var.vpn_customer_gateway.bgp_asn, 65000)
  onprem_cidr                = try(var.vpn_customer_gateway.onprem_cidr, null)
}

module "security" {
  source = "./modules/security"

  providers = {
    aws.management = aws.management
    aws.security   = aws.security
  }

  security_account_id = var.security_account_id
  aws_region          = var.aws_region
  alert_email_address = var.alert_email_address
  enable_guardduty    = var.enable_guardduty
  enable_securityhub  = var.enable_securityhub

  depends_on = [module.organizations]
}

module "logging" {
  source = "./modules/logging"

  providers = {
    aws.management = aws.management
    aws.logging    = aws.logging
  }

  management_account_id  = var.management_account_id
  logging_account_id     = var.logging_account_id
  organization_id        = module.organizations.organization_id
  cloudtrail_bucket_name = var.cloudtrail_bucket_name
  s3_data_event_arns     = var.s3_data_event_arns

  depends_on = [module.organizations]
}
