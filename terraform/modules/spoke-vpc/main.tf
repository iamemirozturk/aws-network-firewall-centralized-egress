variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "transit_gateway_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  private_cidrs    = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  tgw_attach_cidrs = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 240)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in var.availability_zones : az => idx }

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[each.value]
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${each.key}"
    Tier = "private"
  })
}

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

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids                                      = [for az in var.availability_zones : aws_subnet.tgw_attach[az].id]
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.this.id
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw-attach" })
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-rt-private-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# Default route → TGW. No IGW, no NAT — egress is structurally impossible without TGW.
resource "aws_route" "private_default_to_tgw" {
  for_each               = toset(var.availability_zones)
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# VPC Flow Logs — to CloudWatch
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/flowlogs/${var.name_prefix}"
  retention_in_days = 90
  tags              = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-flow-log" })
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "private_subnet_ids" {
  value = { for az in var.availability_zones : az => aws_subnet.private[az].id }
}
