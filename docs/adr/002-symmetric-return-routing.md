# ADR 002: Preserve the stateful return path

## Decision

For every spoke CIDR, route NAT subnet traffic to the same-AZ firewall endpoint, then route from the firewall subnet to Transit Gateway.

## Rejected option

Routing the NAT subnet directly to Transit Gateway was rejected because it bypasses return inspection.

## Consequence

Each AZ and spoke CIDR produces explicit routes that must be validated whenever spokes are added or removed.
