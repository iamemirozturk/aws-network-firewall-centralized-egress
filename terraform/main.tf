################################################################################
# Locals — common tags and naming
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Repository  = "aws-centralized-egress-inspection"
  }
}

################################################################################
# Transit Gateway — hub of the network
################################################################################

module "transit_gateway" {
  source = "./modules/transit-gateway"

  name_prefix    = local.name_prefix
  description    = "TGW for centralized egress inspection"
  spoke_vpc_keys = keys(var.spoke_vpcs)

  tags = local.common_tags
}

################################################################################
# Inspection VPC — hosts the firewall and NAT
################################################################################

module "inspection_vpc" {
  source = "./modules/inspection-vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.inspection_vpc_cidr
  availability_zones = var.availability_zones
  transit_gateway_id = module.transit_gateway.transit_gateway_id

  tags = local.common_tags
}

################################################################################
# Network Firewall — the inspection layer
################################################################################

module "network_firewall" {
  source = "./modules/network-firewall"

  name_prefix            = local.name_prefix
  vpc_id                 = module.inspection_vpc.vpc_id
  firewall_subnet_ids    = module.inspection_vpc.firewall_subnet_ids
  availability_zones     = var.availability_zones
  log_retention_days     = var.log_retention_days
  allowed_egress_domains = var.allowed_egress_domains
  home_net_cidrs         = [for spoke in values(var.spoke_vpcs) : spoke.cidr]
  enable_tls_inspection  = var.enable_tls_inspection
  tls_certificate_arn    = var.tls_inspection_certificate_arn

  tags = local.common_tags
}

################################################################################
# Inspection VPC route programming — depends on firewall endpoints
################################################################################

# Routes from TGW-attach subnets → firewall endpoints (per AZ)
resource "aws_route" "tgw_attach_to_firewall" {
  for_each = {
    for idx, az in var.availability_zones : az => idx
  }

  route_table_id         = module.inspection_vpc.tgw_attach_route_table_ids[each.key]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[each.key]
}

# Routes from firewall subnets → NAT GW (per AZ)
resource "aws_route" "firewall_to_nat" {
  for_each = {
    for idx, az in var.availability_zones : az => idx
  }

  route_table_id         = module.inspection_vpc.firewall_route_table_ids[each.key]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.inspection_vpc.nat_gateway_ids[each.key]
}

# Return path, first hop: NAT subnet → same-AZ firewall endpoint.
resource "aws_route" "nat_to_firewall_for_spokes" {
  for_each = {
    for pair in flatten([
      for az_key, az in var.availability_zones : [
        for spoke_key, spoke in var.spoke_vpcs : {
          key        = "${az}-${spoke_key}"
          az_key     = az
          spoke_cidr = spoke.cidr
        }
      ]
    ]) : pair.key => pair
  }

  route_table_id         = module.inspection_vpc.nat_route_table_ids[each.value.az_key]
  destination_cidr_block = each.value.spoke_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[each.value.az_key]
}

# Return path, second hop: firewall subnet → TGW.
resource "aws_route" "firewall_to_tgw_for_spokes" {
  for_each = {
    for pair in flatten([
      for az in var.availability_zones : [
        for spoke_key, spoke in var.spoke_vpcs : {
          key        = "${az}-${spoke_key}"
          az_key     = az
          spoke_cidr = spoke.cidr
        }
      ]
    ]) : pair.key => pair
  }

  route_table_id         = module.inspection_vpc.firewall_route_table_ids[each.value.az_key]
  destination_cidr_block = each.value.spoke_cidr
  transit_gateway_id     = module.transit_gateway.transit_gateway_id

  depends_on = [module.inspection_vpc]
}

################################################################################
# Spoke VPCs — workload accounts (simulated in single account here)
################################################################################

module "spoke_vpcs" {
  source = "./modules/spoke-vpc"

  for_each = var.spoke_vpcs

  name_prefix        = "${local.name_prefix}-${each.key}"
  vpc_cidr           = each.value.cidr
  availability_zones = var.availability_zones
  transit_gateway_id = module.transit_gateway.transit_gateway_id

  tags = merge(local.common_tags, { SpokeName = each.key })
}

################################################################################
# TGW route table associations and propagations
################################################################################

# Inspection VPC attaches to inspection RT (return path)
resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

# Spokes propagate their CIDRs to the inspection RT (so return packets find them)
resource "aws_ec2_transit_gateway_route_table_propagation" "spokes_to_inspection" {
  for_each = module.spoke_vpcs

  transit_gateway_attachment_id  = each.value.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

# Spokes associate with spokes RT
resource "aws_ec2_transit_gateway_route_table_association" "spokes" {
  for_each = module.spoke_vpcs

  transit_gateway_attachment_id  = each.value.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.spokes_route_table_id
}

# Spokes RT: default route → inspection VPC. This is what forces all egress through inspection.
resource "aws_ec2_transit_gateway_route" "spokes_default_to_inspection" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.spokes_route_table_id
}
