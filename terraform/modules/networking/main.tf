# =============================================================================
# Module: networking
# =============================================================================
# Deploys Zero Trust network architecture:
#   - Private-only VPCs per account (no public subnets in workload accounts)
#   - Transit Gateway for centralized routing
#   - Per-account route table isolation
#   - Centralized NAT Gateway in Network account
#
# Design decision: No internet gateways in workload accounts.
# All outbound internet traffic routes through centralized NAT in the
# Network account. This means a misconfigured security group in a workload
# account cannot expose resources to inbound internet traffic — there is
# no route for it to arrive.
# =============================================================================

# -----------------------------------------------------------------------------
# Transit Gateway — deployed in Network account
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "main" {
  description                     = "Zero Trust central routing hub"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "disable"  # Explicit acceptance required
  default_route_table_association = "disable"  # We manage route tables manually
  default_route_table_propagation = "disable"  # No automatic propagation

  tags = {
    Name    = "zero-trust-tgw"
    Purpose = "centralized-routing"
  }
}

# -----------------------------------------------------------------------------
# Workload VPC — private subnets only
# -----------------------------------------------------------------------------

resource "aws_vpc" "workload" {
  cidr_block           = var.vpc_cidr_workload
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "workload-vpc"
    ZeroTrust = "no-public-subnets"
  }
}

resource "aws_subnet" "workload_private_a" {
  vpc_id            = aws_vpc.workload.id
  cidr_block        = cidrsubnet(var.vpc_cidr_workload, 4, 0)
  availability_zone = "${var.aws_region}a"

  # map_public_ip_on_launch is false by default — explicitly stated for clarity
  map_public_ip_on_launch = false

  tags = {
    Name = "workload-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "workload_private_b" {
  vpc_id            = aws_vpc.workload.id
  cidr_block        = cidrsubnet(var.vpc_cidr_workload, 4, 1)
  availability_zone = "${var.aws_region}b"

  map_public_ip_on_launch = false

  tags = {
    Name = "workload-private-b"
    Tier = "private"
  }
}

# No aws_internet_gateway resource — intentional.
# Workload account has no internet gateway by design.

# -----------------------------------------------------------------------------
# Transit Gateway attachment for workload VPC
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.workload.id
  subnet_ids         = [
    aws_subnet.workload_private_a.id,
    aws_subnet.workload_private_b.id,
  ]

  # Disable default route table association — we use isolated route tables
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "workload-tgw-attachment"
  }
}

# -----------------------------------------------------------------------------
# Route table: workload → Transit Gateway only (no direct internet)
# -----------------------------------------------------------------------------

resource "aws_route_table" "workload_private" {
  vpc_id = aws_vpc.workload.id

  route {
    # All traffic to 0.0.0.0/0 goes via TGW → Network account NAT
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "workload-private-rt"
  }
}

resource "aws_route_table_association" "workload_private_a" {
  subnet_id      = aws_subnet.workload_private_a.id
  route_table_id = aws_route_table.workload_private.id
}

resource "aws_route_table_association" "workload_private_b" {
  subnet_id      = aws_subnet.workload_private_b.id
  route_table_id = aws_route_table.workload_private.id
}
