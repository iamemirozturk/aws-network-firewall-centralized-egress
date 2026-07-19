# Validation guide

Do not convert expected outcomes into claims until you have run these tests.

## Routing inspection

Verify in both AZs:

- Spoke private default route points to TGW.
- TGW spoke route table default points to the inspection attachment.
- TGW-attachment subnet default points to the same-AZ firewall endpoint.
- Firewall subnet default points to the same-AZ NAT gateway.
- NAT subnet default points to the IGW.
- NAT subnet routes every spoke CIDR to the same-AZ firewall endpoint.
- Firewall subnet routes every spoke CIDR to TGW.
- TGW inspection route table contains every spoke CIDR.
- Appliance mode is enabled on the inspection attachment.

## Functional matrix

| Test | Expected | Actual | Evidence |
|---|---|---|---|
| Allowed HTTPS hostname | Allowed | Not tested | Add sanitized output/log |
| Non-allowlisted HTTPS hostname | Blocked | Not tested | Add alert log |
| Allowed HTTP Host | Policy-defined outcome | Not tested | Add output/log |
| UDP/443 | Blocked | Not tested | Add flow evidence |
| Direct-IP HTTPS | Policy-defined outcome | Not tested | Document decision |
| Alternate destination port | Policy-defined outcome | Not tested | Document decision |
| Return path through firewall | Symmetric | Not tested | Route/log evidence |
| AZ impairment | Documented behavior | Not tested | Test or state limitation |
| Terraform destroy | Clean removal | Not tested | Destroy summary |

## Example workload tests

Use domains that you control or are permitted to test:

```bash
curl --connect-timeout 10 -I https://allowed.example
curl --connect-timeout 10 -I https://not-allowed.example
```

Testing UDP/443 requires a client and destination that actually attempt QUIC. A simple UDP probe alone does not prove application fallback behavior. Capture the firewall flow or alert record that supports the conclusion.

## Logs

Use Terraform outputs to obtain the exact log group names:

```bash
terraform output nfw_alert_log_group
terraform output nfw_flow_log_group
```

Correlate timestamps, source address, destination, protocol, and action. Sanitize evidence before publication.

## Acceptance criteria

Publish a validated version only when all mandatory tests pass, limitations are recorded, CI is green, and the tested commit/tag is identifiable.
