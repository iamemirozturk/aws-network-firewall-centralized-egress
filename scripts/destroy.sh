#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

cd "${TF_DIR}"

if [[ "${TF_VAR_enable_firewall_protections:-}" != "false" ]]; then
  cat >&2 <<'EOF'
[!] Cleanup is blocked because Network Firewall protections are enabled by default.

Perform a separate, reviewed Terraform apply that sets:
  enable_firewall_protections = false

After that apply succeeds, explicitly acknowledge the change when running cleanup:
  TF_VAR_enable_firewall_protections=false ./scripts/destroy.sh

This script will never disable firewall protections automatically.
EOF
  exit 1
fi

account_id="$(aws sts get-caller-identity --query Account --output text)"
workspace="$(terraform workspace show)"

echo "[!] Destructive operation requested"
echo "[i] AWS account: ${account_id}"
echo "[i] Terraform workspace: ${workspace}"

terraform plan -destroy -out=tfplan-destroy

read -rp "Type 'destroy ${account_id} ${workspace}' to apply this destroy plan: " confirmation
if [[ "${confirmation}" != "destroy ${account_id} ${workspace}" ]]; then
  echo "[!] Confirmation did not match; no resources were destroyed."
  exit 1
fi

terraform apply tfplan-destroy
echo "[✓] Destroy complete."
