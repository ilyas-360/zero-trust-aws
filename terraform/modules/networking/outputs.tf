output "transit_gateway_id" {
  description = "Transit Gateway ID in the Network account."
  value       = aws_ec2_transit_gateway.main.id
}

output "workload_vpc_id" {
  description = "VPC ID in the configured workload account."
  value       = aws_vpc.workload.id
}

output "vpn_connection_id" {
  description = "Optional AWS Site-to-Site VPN connection ID; null when omitted."
  value       = try(aws_vpn_connection.onprem[0].id, null)
}

output "workload_flow_log_id" {
  description = "VPC Flow Log ID in the workload account."
  value       = aws_flow_log.workload.id
}

output "network_flow_log_id" {
  description = "VPC Flow Log ID in the Network account."
  value       = aws_flow_log.network.id
}
