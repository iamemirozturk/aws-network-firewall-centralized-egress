# Known limitations

- This is a same-account demonstration, not a complete AWS Organizations or landing-zone deployment.
- The module does not automate AWS RAM sharing, cross-account acceptance, centralized state, or delegated administration.
- Network Firewall does not inspect AmazonProvidedDNS traffic. Add DNS Firewall or another approved DNS architecture where required.
- TLS SNI and HTTP Host controls do not inspect full URLs or encrypted payloads.
- Encrypted ClientHello can reduce hostname visibility.
- Direct-IP traffic and non-HTTP/TLS protocols need explicit rules.
- Broad suffix allowlists for shared platforms can permit attacker-controlled tenant resources and create exfiltration paths. Prefer exact hostnames and document every wildcard.
- UDP/443 is blocked. Compatible clients may fall back to TCP; others may fail.
- TLS inspection is optional and unvalidated. It needs certificate distribution, rotation, revocation, bypass, pinning, and mTLS planning.
- The design does not include automated endpoint/NAT failover or chaos testing.
- Centralized routing may add Transit Gateway, Network Firewall, NAT, logging, and cross-AZ charges.
- CloudWatch log groups alone are not an immutable, cross-account security archive.
- Custom and AWS-managed rules can change application behavior and require staged rollout.
- No performance, throughput, latency, recovery-time, or availability claims are made.
- Service quotas and pricing change; verify them in official AWS sources for the deployment region and date.
