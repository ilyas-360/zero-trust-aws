output "organization_id" {
  description = "The AWS Organizations ID"
  value       = aws_organizations_organization.root.id
}

output "root_id" {
  description = "The root OU ID"
  value       = aws_organizations_organization.root.roots[0].id
}

output "workload_ou_id" {
  description = "Workload OU ID — used for account placement"
  value       = aws_organizations_organizational_unit.workload.id
}
