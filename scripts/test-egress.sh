#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# test-egress.sh — Run from inside a spoke VPC EC2 instance (via SSM)
# to validate that the firewall is enforcing the expected policy.
# -----------------------------------------------------------------------------
set -uo pipefail

PASS=0
FAIL=0

declare -a TESTS_PASS=()
declare -a TESTS_FAIL=()

run_test() {
  local name="$1"
  local cmd="$2"
  local expected="$3" # "allow" or "deny"

  echo -n "[~] ${name} ... "
  if eval "${cmd}" > /dev/null 2>&1; then
    actual="allow"
  else
    actual="deny"
  fi

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS (${actual})"
    PASS=$((PASS+1))
    TESTS_PASS+=("${name}")
  else
    echo "FAIL (got: ${actual}, expected: ${expected})"
    FAIL=$((FAIL+1))
    TESTS_FAIL+=("${name}")
  fi
}

echo "================================================================"
echo " AWS Centralized Egress Inspection — Validation Suite"
echo "================================================================"

# --- Allow tests (allowlisted destinations) ---
run_test "Allowlist: aws.amazon.com over HTTPS" \
  "curl -fsS --max-time 5 -o /dev/null https://aws.amazon.com" \
  "allow"

run_test "Allowlist: github.com" \
  "curl -fsS --max-time 5 -o /dev/null https://github.com" \
  "allow"

# --- Deny tests (Suricata custom rules) ---
run_test "Deny: pastebin.com (compliance rule)" \
  "curl -fsS --max-time 5 -o /dev/null https://pastebin.com" \
  "deny"

run_test "Deny: file.io (compliance rule)" \
  "curl -fsS --max-time 5 -o /dev/null https://file.io" \
  "deny"

run_test "Deny: dns.google (DoH block)" \
  "curl -fsS --max-time 5 -o /dev/null https://dns.google" \
  "deny"

# --- QUIC bypass test ---
run_test "Deny: UDP/443 (QUIC stateless drop)" \
  "timeout 3 nc -uz 8.8.8.8 443" \
  "deny"

# --- Direct-to-IP HTTPS (no SNI) ---
run_test "Deny: HTTPS to raw IP (no SNI)" \
  "curl -fsS --max-time 5 -k -o /dev/null https://1.1.1.1" \
  "deny"

echo "================================================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "================================================================"

if [[ ${FAIL} -gt 0 ]]; then
  echo "Failed tests:"
  printf '  - %s\n' "${TESTS_FAIL[@]}"
  exit 1
fi
