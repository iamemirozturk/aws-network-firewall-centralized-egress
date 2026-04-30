variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the inspection VPC."
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs to deploy across."
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit Gateway ID to attach to."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

locals {
  # /20 carve-up of the /16 — generous and human-readable
  # tgw-attach: .0.0/24, .1.0/24
  # firewall:   .2.0/24, .3.0/24
  # nat:        .4.0/24, .5.0/24
  tgw_attach_cidrs = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i)]
  firewall_cidrs   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 2)]
  nat_cidrs        = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 4)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-inspection-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

############################
# Subnets, three tiers per AZ
############################

resource "aws_subnet" "tgw_attach" {
  for_each = { for idx, az in var.availability_zones : az => idx }

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.tgw_attach_cidrs[each.value]
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-attach-${each.key}"
    Tier = "tgw-attach"
  })
}

resource "aws_subnet" "firewall" {
  for_each = { for idx, az in var.availability_zones : az => idx }

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.firewall_cidrs[each.value]
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-firewall-${each.key}"
    Tier = "firewall"
  })
}

resource "aws_subnet" "nat" {
  for_each = { for idx, az in var.availability_zones : az => idx }

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.nat_cidrs[each.value]
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
    Tier = "nat"
  })
}

############################
# NAT Gateways (one per AZ for HA)
############################

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = { for idx, az in var.availability_zones : az => idx }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.nat[each.key].id

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

############################
# TGW Attachment (in tgw-attach subnets)
############################

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids                                      = [for az in var.availability_zones : aws_subnet.tgw_attach[az].id]
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.this.id
  appliance_mode_support                          = "enable" # AZ-affine routing
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-inspection-tgw-attach" })
}

############################
# Route Tables (programmed by parent module after firewall endpoints exist)
############################

resource "aws_route_table" "tgw_attach" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-rt-tgw-attach-${each.key}" })
}

resource "aws_route_table" "firewall" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-rt-firewall-${each.key}" })
}

resource "aws_route_table" "nat" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-rt-nat-${each.key}" })
}

resource "aws_route_table_association" "tgw_attach" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.tgw_attach[each.key].id
  route_table_id = aws_route_table.tgw_attach[each.key].id
}

resource "aws_route_table_association" "firewall" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall[each.key].id
}

resource "aws_route_table_association" "nat" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.nat[each.key].id
  route_table_id = aws_route_table.nat[each.key].id
}

# NAT subnets need IGW route for outbound internet
resource "aws_route" "nat_to_igw" {
  for_each               = toset(var.availability_zones)
  route_table_id         = aws_route_table.nat[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

############################
# Outputs
############################

output "vpc_id" {
  value = aws_vpc.this.id
}

output "firewall_subnet_ids" {
  value = { for az in var.availability_zones : az => aws_subnet.firewall[az].id }
}

output "tgw_attach_route_table_ids" {
  value = { for az in var.availability_zones : az => aws_route_table.tgw_attach[az].id }
}

output "firewall_route_table_ids" {
  value = { for az in var.availability_zones : az => aws_route_table.firewall[az].id }
}

output "nat_route_table_ids" {
  value = { for az in var.availability_zones : az => aws_route_table.nat[az].id }
}

output "nat_gateway_ids" {
  value = { for az in var.availability_zones : az => aws_nat_gateway.this[az].id }
}

output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.this.id
}
