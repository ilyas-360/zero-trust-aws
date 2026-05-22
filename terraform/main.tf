
# =============================================================================
# Zero Trust Multi-Account AWS Security Architecture
# Root Terraform Configuration
# =============================================================================
# This is the root entry point. It calls each module in dependency order:
# 1. Organizations (account structure + SCPs)
# 2. IAM (permission boundaries + role chains)
# 3. Networking (VPCs + Transit Gateway)
# 4. Security (GuardDuty + Security Hub)
# 5. Logging (CloudTrail + S3)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Remote state stored in S3 with DynamoDB locking
    # Configuration in backend.tf
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "zero-trust-aws"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Module: Organizations + SCPs
# Sets up AWS Organizations, OU structure, and attaches Service Control Policies
# -----------------------------------------------------------------------------
module "organizations" {
  source = "./modules/organizations"

  organization_name = var.organization_name
  allowed_regions   = var.allowed_regions
}

# -----------------------------------------------------------------------------
# Module: IAM
# Deploys permission boundaries and cross-account role assumption chains
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  organization_id    = module.organizations.organization_id
  management_account = var.management_account_id
  security_account   = var.security_account_id
  workload_accounts  = var.workload_account_ids

  depends_on = [module.organizations]
}

# -----------------------------------------------------------------------------
# Module: Networking
# Deploys VPCs, Transit Gateway, and route table isolation per account
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  vpc_cidr_management = var.vpc_cidr_management
  vpc_cidr_security   = var.vpc_cidr_security
  vpc_cidr_workload   = var.vpc_cidr_workload
  aws_region          = var.aws_region

  depends_on = [module.organizations]
}

# -----------------------------------------------------------------------------
# Module: Security
# Deploys GuardDuty (delegated admin) and Security Hub aggregation
# -----------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  security_account_id = var.security_account_id
  member_accounts     = var.workload_account_ids
  organization_id     = module.organizations.organization_id

  depends_on = [module.organizations, module.iam]
}

# -----------------------------------------------------------------------------
# Module: Logging
# Deploys organization CloudTrail, VPC Flow Logs, and immutable S3 bucket
# -----------------------------------------------------------------------------
module "logging" {
  source = "./modules/logging"

  logging_account_id  = var.logging_account_id
  organization_id     = module.organizations.organization_id
  log_retention_days  = var.log_retention_days

  depends_on = [module.organizations]
}
