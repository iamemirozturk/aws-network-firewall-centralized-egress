# Security Policy

## Scope

This repository is a deployable reference architecture, not a production certification. Security depends on the selected domains, CIDRs, AWS account controls, Terraform state, deployment identity, and validation performed in the target environment.

## Reporting a vulnerability

Please do not disclose a suspected vulnerability in a public issue. Use GitHub's **Report a vulnerability** option on the repository Security page to submit a private report:

https://github.com/iamemirozturk/aws-network-firewall-centralized-egress/security/advisories/new

Include the affected file or module, impact, reproduction steps, and a suggested remediation when available. Response times are best-effort and are not a service-level commitment.

## Repository controls

| Control | Status |
|---|---|
| Terraform formatting and validation | Automated in GitHub Actions |
| TFLint | Automated in GitHub Actions |
| Checkov and Trivy IaC scanning | Automated in GitHub Actions |
| Gitleaks secret scanning | Automated in GitHub Actions |
| Dependabot for GitHub Actions and Terraform | Configured |
| Network Firewall and CloudWatch Logs encryption | Customer-managed KMS keys in the reference code |
| Firewall deletion and configuration protections | Enabled by default |
| Runtime deployment validation | Required from the adopter; not claimed by this repository |

## Known limitations

- TLS inspection is disabled by default and requires certificate lifecycle, bypass, pinning, and mutual-TLS testing.
- Domain allowlisting is not URL or payload inspection. Broad shared-service suffixes can create exfiltration paths.
- Static analysis does not prove that routes, IAM permissions, KMS permissions, log delivery, Suricata behavior, or failure recovery work in a deployed account.
- CloudWatch log groups in this reference are not a substitute for an immutable, cross-account security archive.
- Review [`docs/limitations.md`](docs/limitations.md) and complete [`docs/validation.md`](docs/validation.md) before adoption.
