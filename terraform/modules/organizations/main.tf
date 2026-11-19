terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management]
    }
  }
}

locals {
  root_policies = {
    deny_root_usage = jsondecode(file("${path.module}/../../../policies/scps/deny-root-usage.json"))
    deny_cloudtrail = jsondecode(file("${path.module}/../../../policies/scps/deny-disable-cloudtrail.json"))
    deny_region     = jsondecode(file("${path.module}/../../../policies/scps/deny-region-restriction.json"))
    require_imdsv2  = jsondecode(file("${path.module}/../../../policies/scps/enforce-imdsv2.json"))
    deny_log_delete = jsondecode(file("${path.module}/../../../policies/scps/deny-delete-cloudtrail-logs.json"))
  }

  clean_policies = {
    for name, policy in local.root_policies : name => {
      for key, value in policy : key => value if !startswith(key, "_")
    }
  }

  region_policy = merge(local.clean_policies.deny_region, {
    Statement = [
      for statement in local.clean_policies.deny_region.Statement :
      statement.Sid == "DenyNonApprovedRegions" ? merge(statement, {
        Condition = merge(statement.Condition, {
          StringNotEquals = merge(statement.Condition.StringNotEquals, {
            "aws:RequestedRegion" = var.allowed_regions
          })
        })
      }) : statement
    ]
  })

  policy_documents = merge(local.clean_policies, {
    deny_region = local.region_policy
  })
}

resource "aws_organizations_organization" "root" {
  provider = aws.management

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  feature_set          = "ALL"
}

resource "aws_organizations_organizational_unit" "security" {
  provider  = aws.management
  name      = "Security"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  provider  = aws.management
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "workload" {
  provider  = aws.management
  name      = "Workload"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_policy" "guardrails" {
  provider = aws.management
  for_each = local.policy_documents

  name = {
    deny_root_usage = "DenyRootUsage"
    deny_cloudtrail = "DenyCloudTrailModification"
    deny_region     = "DenyNonApprovedRegions"
    require_imdsv2  = "RequireIMDSv2"
    deny_log_delete = "DenyCloudTrailLogDeletion"
  }[each.key]

  description = "Zero Trust guardrail: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(each.value)
}

locals {
  ou_ids = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workload       = aws_organizations_organizational_unit.workload.id
  }
  attachment_targets = setunion(toset(values(local.ou_ids)), toset(var.member_account_ids))
  attachment_matrix  = setproduct(local.attachment_targets, toset(keys(aws_organizations_policy.guardrails)))
}

resource "aws_organizations_policy_attachment" "guardrails" {
  provider = aws.management
  for_each = {
    for pair in local.attachment_matrix : "${pair[0]}-${pair[1]}" => {
      target_id = pair[0]
      policy_id = aws_organizations_policy.guardrails[pair[1]].id
    }
  }

  policy_id = each.value.policy_id
  target_id = each.value.target_id
}
