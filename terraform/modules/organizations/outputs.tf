output "organization_id" {
  description = "The AWS Organizations ID"
  value       = aws_organizations_organization.root.id
}

output "organization_arn" {
  description = "AWS Organizations ARN for the AWS RAM resource share."
  value       = aws_organizations_organization.root.arn
}

output "root_id" {
  description = "The root OU ID"
  value       = aws_organizations_organization.root.roots[0].id
}

output "workload_ou_id" {
  description = "Workload OU ID — used for account placement"
  value       = aws_organizations_organizational_unit.workload.id
}
