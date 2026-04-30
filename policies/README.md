# Firewall Policies

This directory holds the **policy-as-code** content for the Network Firewall: stateless drop rules and Suricata stateful rules.

## Structure

```
policies/
├── stateless/
│   └── README.md            # Stateless rules are defined inline in TF
├── suricata-rules/
│   ├── custom.rules         # Active rule set
│   └── README.md            # Rule writing conventions
```

## Rule writing conventions

| Range          | Purpose                          |
|----------------|----------------------------------|
| `1000xxx`      | Reconnaissance / scanning        |
| `2000xxx`      | C2 / malware patterns            |
| `3000xxx`      | High-risk file downloads         |
| `4000xxx`      | Data exfiltration                |
| `5000xxx`      | Compliance / policy denials      |
| `6000xxx`      | DNS-based threats                |

## Promotion workflow

1. Write the rule with `alert` action
2. Deploy to non-prod, observe in alert log for ≥ 1 week
3. Review false positives, refine `content`/`pcre`
4. Promote to `drop` action via PR
5. Annotate with `rev:N+1` and changelog entry below

## Changelog

| Date       | SID(s)  | Change                                  |
|------------|---------|-----------------------------------------|
| 2026-01-15 | 1000001 | Initial port-scan detection             |
| 2026-01-15 | 2000001-2000010 | Initial C2 / DGA TLD set        |
| 2026-01-15 | 3000001-3000004 | High-risk download patterns     |
| 2026-01-15 | 4000001-4000020 | DNS tunneling, DoH, ICMP tunnel |
| 2026-01-15 | 5000001-5000021 | File share / pastebin denials   |
| 2026-01-15 | 6000001 | DGA-like DNS query alert (alert-only)   |
