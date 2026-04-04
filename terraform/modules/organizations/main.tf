# =============================================================================
# Module: organizations
# =============================================================================
# Creates the AWS Organizations structure:
#   - Root organization
#   - Organizational Units (Security, Infrastructure, Workload)
#   - Service Control Policies attached at OU level
#
# Design decision: SCPs are applied at the OU level, not account level.
# This means new accounts added to an OU automatically inherit all guardrails
# without manual policy attachment.
# =============================================================================

resource "aws_organizations_organization" "root" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  feature_set = "ALL" # Required for SCP enforcement
}

# -----------------------------------------------------------------------------
# Organizational Units
# -----------------------------------------------------------------------------

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "workload" {
  name      = "Workload"
  parent_id = aws_organizations_organization.root.roots[0].id
}

# -----------------------------------------------------------------------------
# Service Control Policies
# -----------------------------------------------------------------------------

resource "aws_organizations_policy" "deny_root_usage" {
  name        = "DenyRootUsage"
  description = "Blocks all API calls made with root account credentials"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scps/deny-root-usage.json")
}

resource "aws_organizations_policy" "deny_disable_cloudtrail" {
  name        = "DenyDisableCloudTrail"
  description = "Prevents any principal from disabling or modifying CloudTrail"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scps/deny-disable-cloudtrail.json")
}

resource "aws_organizations_policy" "deny_region_restriction" {
  name        = "DenyNonApprovedRegions"
  description = "Restricts all API calls to approved regions only"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scps/deny-region-restriction.json")
}

resource "aws_organizations_policy" "enforce_imdsv2" {
  name        = "EnforceIMDSv2"
  description = "Forces IMDSv2 on all EC2 instances — prevents SSRF credential theft"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scps/enforce-imdsv2.json")
}

# -----------------------------------------------------------------------------
# Attach SCPs to all OUs
# -----------------------------------------------------------------------------

locals {
  all_ou_ids = [
    aws_organizations_organizational_unit.security.id,
    aws_organizations_organizational_unit.infrastructure.id,
    aws_organizations_organizational_unit.workload.id,
  ]

  scp_ids = [
    aws_organizations_policy.deny_root_usage.id,
    aws_organizations_policy.deny_disable_cloudtrail.id,
    aws_organizations_policy.deny_region_restriction.id,
    aws_organizations_policy.enforce_imdsv2.id,
  ]
}

resource "aws_organizations_policy_attachment" "scp_attachments" {
  for_each = {
    for pair in setproduct(local.all_ou_ids, local.scp_ids) :
    "${pair[0]}-${pair[1]}" => { ou_id = pair[0], scp_id = pair[1] }
  }

  policy_id = each.value.scp_id
  target_id = each.value.ou_id
}
