# Troubleshooting

## No outbound connectivity

Check the forward route chain in order: spoke subnet, TGW spoke table, TGW-attachment subnet, firewall subnet, NAT subnet, and IGW. Confirm the firewall endpoint and NAT gateway are in the intended AZ and available.

## Connections start but TLS fails

Inspect alert logs for hostname policy decisions. Confirm the domain is represented correctly in the allowlist and that `HOME_NET` includes the source spoke CIDR. If TLS inspection is enabled, test certificate trust and pinning separately.

## Replies bypass the firewall

The NAT subnet route for each spoke CIDR must target the same-AZ firewall endpoint. The firewall subnet route for each spoke CIDR must target TGW. A NAT-to-TGW shortcut is incorrect for this design.

## Intermittent stateful drops

Look for cross-AZ or asymmetric routing. Confirm appliance mode on the inspection attachment and per-AZ route-table associations. Correlate flow logs in both directions.

## Domain rules never match

Confirm the source is inside the explicit `HOME_NET`, the traffic exposes TLS SNI or HTTP Host, and the protocol reaches the stateful engine. ECH, direct-IP traffic, QUIC, and non-HTTP/TLS protocols require different handling.

## Terraform cannot destroy resources

Check for resources or route dependencies created outside this configuration. Disable protection only after confirming the correct account and target. Never remove state entries merely to hide an undeleted AWS resource.
