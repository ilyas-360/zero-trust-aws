terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.network, aws.workload]
    }
  }
}

data "aws_availability_zones" "network" {
  provider = aws.network
  state    = "available"
}

data "aws_availability_zones" "workload" {
  provider = aws.workload
  state    = "available"
}

locals {
  network_azs  = slice(data.aws_availability_zones.network.names, 0, 2)
  workload_azs = slice(data.aws_availability_zones.workload.names, 0, 2)
  workload_subnets = {
    for index, cidr in var.workload_subnet_cidrs : tostring(index) => {
      cidr = cidr
      az   = local.workload_azs[index]
    }
  }
}

resource "aws_ec2_transit_gateway" "main" {
  provider = aws.network

  description                     = "Zero Trust hub routing between the workload and network accounts."
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name    = "zero-trust-tgw"
    Purpose = "centralized-routing"
  }
}

resource "aws_ram_sharing_with_organization" "main" {
  provider = aws.management
  enabled  = true
}

resource "aws_ram_resource_share" "transit_gateway" {
  provider = aws.network

  name                      = "zero-trust-transit-gateway-share"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "transit_gateway" {
  provider = aws.network

  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.transit_gateway.arn
}

resource "aws_ram_principal_association" "organization" {
  provider = aws.network

  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.transit_gateway.arn
  depends_on         = [aws_ram_sharing_with_organization.main]
}

resource "aws_vpc" "network" {
  provider = aws.network

  cidr_block           = var.network_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "zero-trust-network-vpc"
    Tier = "egress"
  }
}

resource "aws_internet_gateway" "network" {
  provider = aws.network
  vpc_id   = aws_vpc.network.id

  tags = {
    Name = "zero-trust-egress-igw"
  }
}

resource "aws_subnet" "network_public" {
  provider = aws.network
  count    = 1

  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.network_vpc_cidr, 8, 1)
  availability_zone       = local.network_azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "network-egress-public-a"
    Tier = "public-egress-only"
  }
}

resource "aws_subnet" "network_tgw" {
  provider = aws.network
  count    = 2

  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.network_vpc_cidr, 8, count.index + 2)
  availability_zone       = local.network_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "network-tgw-${count.index + 1}"
    Tier = "private-transit"
  }
}

resource "aws_route_table" "network_public" {
  provider = aws.network
  vpc_id   = aws_vpc.network.id

  tags = {
    Name = "network-egress-public-rt"
  }
}

resource "aws_route" "network_public_internet" {
  provider               = aws.network
  route_table_id         = aws_route_table.network_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.network.id
}

resource "aws_route_table_association" "network_public" {
  provider       = aws.network
  subnet_id      = aws_subnet.network_public[0].id
  route_table_id = aws_route_table.network_public.id
}

resource "aws_route_table" "network_tgw" {
  provider = aws.network
  vpc_id   = aws_vpc.network.id

  tags = {
    Name = "network-tgw-subnet-rt"
  }
}

resource "aws_route_table_association" "network_tgw" {
  provider       = aws.network
  count          = 2
  subnet_id      = aws_subnet.network_tgw[count.index].id
  route_table_id = aws_route_table.network_tgw.id
}

resource "aws_eip" "nat" {
  provider = aws.network
  count    = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"
  tags = {
    Name = "zero-trust-egress-nat-eip"
  }
}

resource "aws_nat_gateway" "egress" {
  provider = aws.network
  count    = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.network_public[0].id
  depends_on    = [aws_internet_gateway.network]

  tags = {
    Name = "zero-trust-egress-nat"
  }
}

resource "aws_route" "network_tgw_to_nat" {
  provider               = aws.network
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.network_tgw.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.egress[0].id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "network" {
  provider = aws.network

  subnet_ids         = aws_subnet.network_tgw[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.network.id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "network-vpc-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_route_table" "workload" {
  provider           = aws.network
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "zero-trust-workload-rt"
    Tier = "workload-isolation"
  }
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  provider           = aws.network
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "zero-trust-egress-rt"
    Tier = "controlled-egress"
  }
}

resource "aws_ec2_transit_gateway_route_table" "onprem" {
  provider           = aws.network
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "zero-trust-onprem-rt"
    Tier = "hybrid-access"
  }
}

resource "aws_vpc" "workload" {
  provider = aws.workload

  cidr_block           = var.workload_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "zero-trust-workload-vpc"
    ZeroTrust = "private-subnets"
  }
}

resource "aws_subnet" "workload_private" {
  provider = aws.workload
  for_each = local.workload_subnets

  vpc_id                  = aws_vpc.workload.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "workload-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_route_table" "workload_private" {
  provider = aws.workload
  vpc_id   = aws_vpc.workload.id

  tags = {
    Name = "workload-private-rt"
  }
}

resource "aws_route_table_association" "workload_private" {
  provider       = aws.workload
  for_each       = aws_subnet.workload_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.workload_private.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  provider = aws.workload

  subnet_ids         = values(aws_subnet.workload_private)[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.workload.id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  depends_on = [
    aws_ram_resource_association.transit_gateway,
    aws_ram_principal_association.organization
  ]

  tags = {
    Name = "workload-vpc-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "workload" {
  provider = aws.network

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload.id
}

resource "aws_ec2_transit_gateway_route_table_association" "workload" {
  provider                       = aws.network
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment_accepter.workload.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.workload.id
}

resource "aws_ec2_transit_gateway_route_table_association" "network" {
  provider                       = aws.network
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# Return traffic arriving through the Network VPC attachment must be sent
# back through the Transit Gateway to the workload VPC, not to the NAT.
resource "aws_route" "network_tgw_to_workload" {
  provider               = aws.network
  route_table_id         = aws_route_table.network_tgw.id
  destination_cidr_block = var.workload_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route" "workload_default_to_egress" {
  provider                       = aws.network
  count                          = var.enable_nat_gateway ? 1 : 0
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.workload.id
}

resource "aws_ec2_transit_gateway_route" "egress_to_workload" {
  provider                       = aws.network
  destination_cidr_block         = var.workload_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

resource "aws_route" "workload_default_to_tgw" {
  provider               = aws.workload
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.workload_private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "network_return_to_workload" {
  provider               = aws.network
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.network_public.id
  destination_cidr_block = var.workload_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_customer_gateway" "onprem" {
  provider = aws.network
  count    = var.customer_gateway_public_ip == null ? 0 : 1

  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "zero-trust-onprem-customer-gateway"
  }
}

resource "aws_vpn_connection" "onprem" {
  provider = aws.network
  count    = var.customer_gateway_public_ip == null ? 0 : 1

  customer_gateway_id = aws_customer_gateway.onprem[0].id
  transit_gateway_id  = aws_ec2_transit_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = false

  tags = {
    Name = "zero-trust-onprem-vpn"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "onprem" {
  provider                       = aws.network
  count                          = var.customer_gateway_public_ip == null ? 0 : 1
  transit_gateway_attachment_id  = aws_vpn_connection.onprem[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem.id
}

resource "aws_ec2_transit_gateway_route" "onprem_to_workload" {
  provider                       = aws.network
  count                          = var.customer_gateway_public_ip == null ? 0 : 1
  destination_cidr_block         = var.workload_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "onprem_to_workload" {
  provider                       = aws.network
  count                          = var.customer_gateway_public_ip == null ? 0 : 1
  transit_gateway_attachment_id  = aws_vpn_connection.onprem[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.workload.id
}

resource "aws_route" "workload_to_onprem" {
  provider               = aws.workload
  count                  = var.onprem_cidr == null ? 0 : 1
  route_table_id         = aws_route_table.workload_private.id
  destination_cidr_block = var.onprem_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_route_table_propagation.onprem_to_workload]
}

resource "aws_cloudwatch_log_group" "workload_flow_logs" {
  provider          = aws.workload
  name              = "/aws/vpc/zero-trust-workload-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

resource "aws_iam_role" "workload_flow_logs" {
  provider = aws.workload
  name     = "VpcFlowLogsDeliveryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.workload_account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${var.workload_account_id}:vpc/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "workload_flow_logs" {
  provider = aws.workload
  name     = "VpcFlowLogsDelivery"
  role     = aws_iam_role.workload_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.workload_flow_logs.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "workload" {
  provider             = aws.workload
  log_destination      = aws_cloudwatch_log_group.workload_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.workload_flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.workload.id

  depends_on = [aws_iam_role_policy.workload_flow_logs]
}

resource "aws_cloudwatch_log_group" "network_flow_logs" {
  provider          = aws.network
  name              = "/aws/vpc/zero-trust-network-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

resource "aws_iam_role" "network_flow_logs" {
  provider = aws.network
  name     = "VpcFlowLogsDeliveryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.network_account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${var.network_account_id}:vpc/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "network_flow_logs" {
  provider = aws.network
  name     = "VpcFlowLogsDelivery"
  role     = aws_iam_role.network_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.network_flow_logs.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "network" {
  provider             = aws.network
  log_destination      = aws_cloudwatch_log_group.network_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.network_flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.network.id

  depends_on = [aws_iam_role_policy.network_flow_logs]
}
