# ADR 003: Declare centralized sources as HOME_NET

## Decision

Populate the stateful rule group's `HOME_NET` with every spoke CIDR.

## Rationale

The protected sources reside outside the inspection VPC. Relying on the firewall VPC CIDR would not describe the centralized traffic sources correctly.

## Consequence

Spoke CIDRs become policy input and must remain accurate and non-overlapping.
