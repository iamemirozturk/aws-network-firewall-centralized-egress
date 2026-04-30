variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "description" {
  type        = string
  description = "Description applied to the TGW."
}

variable "spoke_vpc_keys" {
  type        = list(string)
  description = "Names of the spoke VPCs (used for tagging only)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  multicast_support               = "disable"

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw" })
}

# Two route tables: spokes (forces egress through inspection) and inspection (return path).
resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name_prefix}-tgw-rt-spokes" })
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name_prefix}-tgw-rt-inspection" })
}

output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "spokes_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.spokes.id
}

output "inspection_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.inspection.id
}
