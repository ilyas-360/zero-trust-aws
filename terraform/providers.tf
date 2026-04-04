# =============================================================================
# Provider Configuration
# =============================================================================
# Multi-account deployments require provider aliases — one per account.
# Each module receives the appropriate provider via provider = aws.<alias>
# =============================================================================

provider "aws" {
  alias  = "management"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.management_account_id}:role/TerraformDeployRole"
  }
}

provider "aws" {
  alias  = "security"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/TerraformDeployRole"
  }
}

provider "aws" {
  alias  = "logging"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.logging_account_id}:role/TerraformDeployRole"
  }
}

provider "aws" {
  alias  = "network"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_account_id}:role/TerraformDeployRole"
  }
}
