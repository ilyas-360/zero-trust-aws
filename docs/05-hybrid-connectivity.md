# 05 — Hybrid Connectivity

> **Status: optional Terraform configuration.** No VPN is created when `vpn_customer_gateway = null`, which is the example default. The repository does not deploy or configure a customer gateway appliance.

## Implemented Terraform scope

When a customer-gateway object is supplied, Terraform creates an AWS Customer Gateway using its public IP and BGP ASN, a Site-to-Site VPN attached to the Network-account Transit Gateway, a VPN route-table association, and route propagation for learned on-premises prefixes. The Workload VPC gets a route for the configured on-premises CIDR.

This requires a reachable external IPsec/BGP device. It can be a physical lab device or a separately managed Linux VPN appliance. The appliance configuration, public IP, BGP ASN, firewall rules, and IPsec secrets are not created by this module. Keep downloaded configurations and secrets private.

## Configure the endpoint and capture proof

1. In `terraform/terraform.tfvars`, set `vpn_customer_gateway` to an object containing the device `public_ip`, its `bgp_asn`, and the `onprem_cidr` it advertises. Keep the object null until the device is ready.
2. Run `terraform plan` and confirm the plan contains one `aws_customer_gateway`, one `aws_vpn_connection`, the VPN route-table association, propagation, and the workload route.
3. After an approved apply, open **AWS Console → VPC → Site-to-Site VPN connections** in the Network account and select the new connection.
4. Choose **Download configuration**, select the customer-gateway vendor/platform/software, and download the generated device configuration. Treat it as sensitive; do not commit it or publish its tunnel secrets.
5. Configure the device with both tunnels and BGP. Wait until both tunnel states show **UP** before testing.
6. From a test host, verify one allowed connection to a workload private address and one blocked path. Confirm route tables and Flow Logs in the Network and Workload accounts.
7. Save sanitized console and terminal screenshots as `11-connectivity-test.png` and update `verification/security-validation.md` with timestamps and results.

The route table is not proof that a VPN is operational. The endpoint must complete IKE/IPsec negotiation and exchange the expected routes before connectivity can be claimed.
