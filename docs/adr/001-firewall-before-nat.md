# ADR 001: Inspect before source NAT

## Decision

Route spoke traffic through Network Firewall before NAT Gateway.

## Rationale

The firewall retains the workload's private source address for policy and investigation. NAT remains the final translation step before the internet.

## Consequence

Return routing must traverse the firewall again. Separate NAT and firewall subnet route tables are required.
