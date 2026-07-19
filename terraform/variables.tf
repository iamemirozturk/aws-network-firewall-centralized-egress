variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project identifier used in tagging and resource naming."
  type        = string
  default     = "egress-inspection"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod). Used in tagging."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual owning the resources."
  type        = string
  default     = "security-platform"
}

variable "availability_zones" {
  description = "Two AZs to deploy across. Must support Network Firewall and TGW."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "This reference uses exactly two AZs."
  }
}

variable "inspection_vpc_cidr" {
  description = "CIDR for the inspection VPC."
  type        = string
  default     = "100.64.0.0/16"
}

variable "spoke_vpcs" {
  description = "Map of spoke VPCs to deploy. Key is the spoke name."
  type = map(object({
    cidr = string
  }))
  default = {
    "spoke-app-a" = { cidr = "10.20.0.0/16" }
    "spoke-app-b" = { cidr = "10.30.0.0/16" }
  }
}

variable "log_retention_days" {
  description = "Retention for CloudWatch log groups."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Must be a valid CloudWatch Logs retention value."
  }
}

variable "enable_firewall_protections" {
  description = "Enable Network Firewall deletion and configuration-change protections. Disable in a reviewed apply before destroying the lab."
  type        = bool
  default     = true
}

variable "enable_tls_inspection" {
  description = "Enable TLS inspection on the firewall policy. Requires a CA cert in ACM."
  type        = bool
  default     = false
}

variable "tls_inspection_certificate_arn" {
  description = "ACM ARN of the CA certificate for TLS inspection. Required when enable_tls_inspection is true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_egress_domains" {
  description = "Domains permitted via TLS SNI / HTTP Host matching."
  type        = list(string)

  validation {
    condition     = length(var.allowed_egress_domains) > 0
    error_message = "Provide at least one explicitly approved egress domain."
  }
}
