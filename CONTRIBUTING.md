# Contributing

Contributions are welcome. This repo aims to be a high-quality reference for AWS egress security architectures, so changes should align with that goal.

## Quick start

```bash
git clone https://github.com/iamemirozturk/aws-network-firewall-centralized-egress.git
cd aws-network-firewall-centralized-egress
pre-commit install
```

## Before opening a PR

1. **Run pre-commit hooks** — `pre-commit run --all-files`
2. **Validate Terraform** — `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform fmt -check -recursive && terraform -chdir=terraform validate`
3. **Run security scans** locally:
   ```bash
   checkov -d terraform/
   trivy config terraform/
   ```
4. **Update docs** — README and ARCHITECTURE if you change behavior
5. **Don't commit `terraform.tfvars`, `*.tfstate`, or `.terraform/`** — covered by `.gitignore`

## Commit conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(firewall): add Suricata rule for DNS tunneling detection
fix(routing): correct AZ-affine route in spoke module
docs(readme): clarify NAT placement rationale
```

## What makes a good PR

- ✅ Solves one thing
- ✅ Includes a description of *why*, not just *what*
- ✅ Updated tests / examples
- ✅ Passes CI
- ✅ Backwards compatible, or includes a migration note

## Code style

- Terraform: `terraform fmt`-clean, no unused variables, all variables typed and described
- Bash: `set -euo pipefail` at top of every script; `shellcheck`-clean
- YAML: 2-space indent

## Licensing

By contributing, you agree your work will be released under the [MIT License](LICENSE).
