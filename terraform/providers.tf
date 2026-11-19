locals {
  project_tags = {
    Project     = "zero-trust-aws"
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

# Each account alias uses a separate AWS CLI profile. Configure those profiles
# with IAM Identity Center; the account-ID guard prevents an accidental apply
# through the wrong profile. No access keys are stored in Terraform files.
provider "aws" {
  alias               = "management"
  region              = var.aws_region
  profile             = var.management_profile
  allowed_account_ids = [var.management_account_id]

  default_tags {
    tags = local.project_tags
  }
}

provider "aws" {
  alias               = "security"
  region              = var.aws_region
  profile             = var.security_profile
  allowed_account_ids = [var.security_account_id]

  default_tags {
    tags = local.project_tags
  }
}

provider "aws" {
  alias               = "logging"
  region              = var.aws_region
  profile             = var.logging_profile
  allowed_account_ids = [var.logging_account_id]

  default_tags {
    tags = local.project_tags
  }
}

provider "aws" {
  alias               = "network"
  region              = var.aws_region
  profile             = var.network_profile
  allowed_account_ids = [var.network_account_id]

  default_tags {
    tags = local.project_tags
  }
}

provider "aws" {
  alias               = "workload"
  region              = var.aws_region
  profile             = var.workload_profile
  allowed_account_ids = [var.workload_account_id]

  default_tags {
    tags = local.project_tags
  }
}
