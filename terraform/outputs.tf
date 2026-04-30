output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = module.transit_gateway.transit_gateway_id
}

output "inspection_vpc_id" {
  description = "Inspection VPC ID."
  value       = module.inspection_vpc.vpc_id
}

output "network_firewall_arn" {
  description = "ARN of the deployed Network Firewall."
  value       = module.network_firewall.firewall_arn
}

output "firewall_endpoint_ids_by_az" {
  description = "VPC Endpoint IDs of the firewall, keyed by AZ."
  value       = module.network_firewall.firewall_endpoint_ids
}

output "spoke_vpc_ids" {
  description = "Spoke VPC IDs by name."
  value       = { for k, v in module.spoke_vpcs : k => v.vpc_id }
}

output "nfw_alert_log_group" {
  description = "CloudWatch log group for NFW alert logs."
  value       = module.network_firewall.alert_log_group_name
}

output "nfw_flow_log_group" {
  description = "CloudWatch log group for NFW flow logs."
  value       = module.network_firewall.flow_log_group_name
}
