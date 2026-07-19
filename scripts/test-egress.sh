#!/usr/bin/env bash
set -u

# Run from an authorized test workload in a spoke VPC.
# Example:
# ALLOWED_URL=https://aws.amazon.com BLOCKED_URL=https://example.org ./test-egress.sh

allowed_url="${ALLOWED_URL:-}"
blocked_url="${BLOCKED_URL:-}"

if [[ -z "${allowed_url}" || -z "${blocked_url}" ]]; then
  echo "Set ALLOWED_URL and BLOCKED_URL to destinations you are authorized to test."
  exit 2
fi

failures=0

if curl --fail --silent --show-error --connect-timeout 10 --output /dev/null "${allowed_url}"; then
  echo "PASS: allowed URL succeeded"
else
  echo "FAIL: allowed URL did not succeed"
  failures=$((failures + 1))
fi

if curl --fail --silent --show-error --connect-timeout 10 --output /dev/null "${blocked_url}"; then
  echo "FAIL: blocked URL succeeded"
  failures=$((failures + 1))
else
  echo "PASS: blocked URL did not succeed"
fi

echo "Inspect Network Firewall logs to prove the policy action; curl failure alone is not sufficient evidence."
exit "${failures}"
