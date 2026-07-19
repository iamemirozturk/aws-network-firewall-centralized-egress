variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "vpc_id" {
  type        = string
  description = "Inspection VPC ID."
}

variable "firewall_subnet_ids" {
  type        = map(string)
  description = "Map of AZ → firewall subnet ID."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for logs."
}

variable "allowed_egress_domains" {
  type        = list(string)
  description = "Domains permitted via TLS SNI / HTTP Host."
}

variable "home_net_cidrs" {
  type        = list(string)
  description = "Spoke CIDRs treated as HOME_NET by centralized stateful rules."

  validation {
    condition     = length(var.home_net_cidrs) > 0
    error_message = "At least one spoke CIDR must be supplied for HOME_NET."
  }
}

variable "enable_tls_inspection" {
  type        = bool
  description = "Enable TLS inspection. Requires a CA cert."
}

variable "tls_certificate_arn" {
  type        = string
  description = "ACM ARN of the CA certificate."
  sensitive   = true
}

variable "enable_protections" {
  type        = bool
  description = "Enable firewall deletion and configuration-change protections."
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

################################################################################
# KMS key for log encryption
################################################################################

resource "aws_kms_key" "logs" {
  description             = "KMS key for Network Firewall logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-nfw-logs-kms" })
}

resource "aws_kms_key_policy" "logs" {
  key_id = aws_kms_key.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

################################################################################
# CloudWatch Log Groups for NFW alert + flow logs
################################################################################

resource "aws_cloudwatch_log_group" "alert" {
  name              = "/aws/network-firewall/${var.name_prefix}/alert"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/network-firewall/${var.name_prefix}/flow"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = var.tags
}

################################################################################
# Stateless rule group — drop QUIC and obviously unwanted traffic up front
################################################################################

resource "aws_networkfirewall_rule_group" "stateless_drops" {
  name     = "${var.name_prefix}-stateless-drops"
  capacity = 100
  type     = "STATELESS"

  encryption_configuration {
    key_id = aws_kms_key.logs.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        # Rule 1: drop UDP/443 (QUIC) — prevent inspection bypass
        stateless_rule {
          priority = 10
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              protocols = [17] # UDP
              destination_port {
                from_port = 443
                to_port   = 443
              }
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }

        # Rule 2: drop UDP/80 — abnormal, often C2
        stateless_rule {
          priority = 20
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              protocols = [17]
              destination_port {
                from_port = 80
                to_port   = 80
              }
              source { address_definition = "0.0.0.0/0" }
              destination { address_definition = "0.0.0.0/0" }
            }
          }
        }
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-stateless-drops" })
}

################################################################################
# Stateful rule group — domain allowlist (TLS SNI / HTTP Host)
################################################################################

resource "aws_networkfirewall_rule_group" "domain_allowlist" {
  name     = "${var.name_prefix}-domain-allowlist"
  capacity = 200
  type     = "STATEFUL"

  encryption_configuration {
    key_id = aws_kms_key.logs.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = var.home_net_cidrs
        }
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        targets              = var.allowed_egress_domains
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-domain-allowlist" })
}

################################################################################
# Stateful rule group — custom Suricata rules
################################################################################

resource "aws_networkfirewall_rule_group" "suricata_custom" {
  name     = "${var.name_prefix}-suricata-custom"
  capacity = 500
  type     = "STATEFUL"

  encryption_configuration {
    key_id = aws_kms_key.logs.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"

        ip_set {
          definition = var.home_net_cidrs
        }
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      rules_string = file("${path.module}/../../../policies/suricata-rules/custom.rules")
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-suricata-custom" })
}

################################################################################
# Firewall Policy — composes rule groups in deterministic order
################################################################################

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name_prefix}-policy"

  encryption_configuration {
    key_id = aws_kms_key.logs.arn
    type   = "CUSTOMER_KMS"
  }

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    # Application-layer allowlists need the TCP/TLS session to become
    # established before an unmatched flow is dropped.
    stateful_default_actions = [
      "aws:drop_established",
      "aws:alert_established",
    ]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateless_rule_group_reference {
      priority     = 10
      resource_arn = aws_networkfirewall_rule_group.stateless_drops.arn
    }

    stateful_rule_group_reference {
      priority     = 100
      resource_arn = "arn:aws:network-firewall:${data.aws_region.current.region}:aws-managed:stateful-rulegroup/ThreatSignaturesEmergingEventsStrictOrder"
    }

    stateful_rule_group_reference {
      priority     = 200
      resource_arn = aws_networkfirewall_rule_group.suricata_custom.arn
    }

    stateful_rule_group_reference {
      priority     = 300
      resource_arn = aws_networkfirewall_rule_group.domain_allowlist.arn
    }

    tls_inspection_configuration_arn = var.enable_tls_inspection ? aws_networkfirewall_tls_inspection_configuration.this[0].arn : null
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-policy" })
}

################################################################################
# TLS Inspection Configuration (optional)
################################################################################

resource "aws_networkfirewall_tls_inspection_configuration" "this" {
  count = var.enable_tls_inspection ? 1 : 0

  name = "${var.name_prefix}-tls-inspection"

  tls_inspection_configuration {
    server_certificate_configuration {
      certificate_authority_arn = var.tls_certificate_arn

      scope {
        protocols = [6] # TCP

        destination_ports {
          from_port = 443
          to_port   = 443
        }

        destination {
          address_definition = "0.0.0.0/0"
        }

        source {
          address_definition = "0.0.0.0/0"
        }
      }
    }
  }

  tags = var.tags
}

################################################################################
# Network Firewall — actual deployment
################################################################################

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-fw"
  vpc_id              = var.vpc_id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn

  encryption_configuration {
    key_id = aws_kms_key.logs.arn
    type   = "CUSTOMER_KMS"
  }

  delete_protection                 = var.enable_protections
  firewall_policy_change_protection = var.enable_protections
  subnet_change_protection          = var.enable_protections

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-fw" })
}

################################################################################
# Logging Configuration
################################################################################

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}

################################################################################
# Outputs
################################################################################

output "firewall_arn" {
  value = aws_networkfirewall_firewall.this.arn
}

output "firewall_endpoint_ids" {
  description = "Map of AZ → VPCE ID of the firewall endpoint in that AZ."
  value = {
    for sync in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    sync.availability_zone => one([for ep in sync.attachment : ep.endpoint_id])
  }
}

output "alert_log_group_name" {
  value = aws_cloudwatch_log_group.alert.name
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow.name
}
