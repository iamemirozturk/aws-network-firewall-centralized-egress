#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# trigger-detection.sh — Generate test traffic to validate detection pipeline.
# Run from inside a spoke VPC EC2 instance (via SSM Session Manager).
#
# This is for tabletop / IR drills: it deliberately triggers blocked rules
# so you can verify that:
#   1. The firewall blocks the traffic
#   2. Alerts appear in CloudWatch within expected SLA
#   3. Downstream SIEM / alerting pipeline fires
# -----------------------------------------------------------------------------
set -uo pipefail

bash_pid=$$
echo "[i] PID: ${bash_pid}, source IP: $(hostname -I | awk '{print $1}')"
echo "[i] Triggering deliberate egress policy violations..."
echo

trigger() {
  local label="$1"
  local cmd="$2"
  echo "[~] ${label}"
  eval "${cmd}" > /dev/null 2>&1 || true
  sleep 1
}

# 1. Pastebin attempt
trigger "Pastebin (sid:5000020)" \
  "curl --max-time 3 https://pastebin.com"

# 2. DNS-over-HTTPS attempt
trigger "DoH to dns.google (sid:4000010)" \
  "curl --max-time 3 https://dns.google"

# 3. Suspicious TLD
trigger "Suspicious TLD .xyz (sid:2000002)" \
  "curl --max-time 3 https://example.xyz"

# 4. QUIC
trigger "QUIC UDP/443 (stateless drop)" \
  "timeout 2 nc -u 8.8.8.8 443"

# 5. Direct-to-IP TLS (no SNI)
trigger "TLS without SNI (sid:2000010)" \
  "curl --max-time 3 -k https://1.1.1.1"

echo
echo "[✓] Triggers complete. Now check:"
echo "    aws logs tail /aws/network-firewall/<name>/alert --since 5m"
echo
echo "[i] Expected: 5 'blocked' events in alert log within ~30 seconds."
