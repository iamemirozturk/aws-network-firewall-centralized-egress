#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# deploy.sh — Wrapper for deploying the egress inspection stack.
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

cd "${TF_DIR}"

if [[ ! -f terraform.tfvars ]]; then
  echo "[!] terraform.tfvars not found. Copy from terraform.tfvars.example and edit."
  exit 1
fi

echo "[+] terraform init"
terraform init

echo "[+] terraform fmt -check"
terraform fmt -check -recursive

echo "[+] terraform validate"
terraform validate

echo "[+] terraform plan"
terraform plan -out=tfplan

read -rp "Apply this plan? [yes/no]: " confirm
if [[ "${confirm}" != "yes" ]]; then
  echo "[!] Aborted."
  rm -f tfplan
  exit 1
fi

echo "[+] terraform apply"
terraform apply tfplan
rm -f tfplan

echo
echo "[✓] Deployment complete."
echo "[i] To validate, run: ./scripts/test-egress.sh"
