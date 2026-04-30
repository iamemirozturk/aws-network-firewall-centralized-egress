# Security Policy

## Scope

This repository provides reference Terraform code and configurations for a centralized AWS egress inspection architecture. The code is intended for **educational and reference purposes**. Before deploying to production, conduct a security review against your organization's standards.

## Reporting a Vulnerability

If you discover a security issue in this code (insecure defaults, misconfiguration, exposed secrets, etc.), please **do not open a public GitHub issue**.

Instead, please email the maintainer directly with:

- A clear description of the vulnerability
- Steps to reproduce
- The Terraform module and version affected
- Suggested remediation, if you have one

You can expect:

- Acknowledgement within **48 hours**
- A status update within **7 days**
- Public credit (or anonymous, if you prefer) once the issue is resolved

## Security Posture of This Repository

| Control | Status |
|---------|--------|
| Pre-commit hooks (gitleaks, terraform fmt/validate) | ✅ Configured |
| CI security scanning (Checkov, tfsec) | ✅ Configured |
| Dependabot for Terraform provider updates | ✅ Configured |
| No hard-coded credentials | ✅ Verified |
| Sensitive variables marked `sensitive = true` | ✅ Yes |
| SSE-KMS on all data resources | ✅ Yes |
| Least-privilege IAM | ✅ Yes |

## Known Limitations

- The example configuration enables CloudWatch log export. Review log retention against your data classification policy.
- TLS inspection is **disabled by default**. Enabling it requires careful CA-management decisions; see [`ARCHITECTURE.md`](ARCHITECTURE.md#tls-inspection-when-and-when-not).
- Default Suricata rules are conservative; tune for your environment.
