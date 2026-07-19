#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# destroy.sh — Tear down the egress inspection stack.
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

cd "${TF_DIR}"

echo "[!] This will destroy the entire egress inspection stack."
read -rp "Type 'destroy' to confirm: " confirm
if [[ "${confirm}" != "destroy" ]]; then
  echo "[!] Aborted."
  exit 1
fi

terraform destroy -auto-approve
echo "[✓] Destroy complete."
