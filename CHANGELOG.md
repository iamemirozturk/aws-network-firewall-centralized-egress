# Changelog

## 2.0.0

- Corrected the return path so NAT subnets route spoke CIDRs to the same-AZ firewall endpoint.
- Added firewall-subnet routes from spoke CIDRs to Transit Gateway.
- Added explicit `HOME_NET` for centralized spoke CIDRs.
- Replaced early strict drops with established-flow default actions for application-layer hostname evaluation.
- Limited appliance mode to the inspection attachment.
- Corrected architecture and multi-AZ explanations.
- Added deployment, validation, limitations, troubleshooting, ADR, and screenshot guidance.
- Removed unsupported production, performance, quota, and validation claims.
- Updated CI branch targets to the repository's `aws` branch.
