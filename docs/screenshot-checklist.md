# Publication evidence checklist

Capture only from a lab you are authorized to publish. Redact account IDs, ARNs where sensitive, public IPs, internal domains, customer names, ticket numbers, and identifying tags.

- Architecture and traffic-flow diagrams
- TGW attachments and separate route tables
- Appliance mode enabled on the inspection attachment
- Spoke private subnet routes
- Inspection TGW-attachment subnet routes for both AZs
- Firewall subnet routes for both AZs
- NAT subnet routes for both AZs
- Network Firewall endpoints and health
- Firewall policy and strict-order configuration
- Domain rule group with sanitized targets and `HOME_NET`
- UDP/443 stateless rule
- Sanitized alert and flow log evidence
- Allowed and blocked test outputs
- Terraform format/validate/plan result
- GitHub Actions result
- Successful destroy result or documented retained lab

Every screenshot should have a caption explaining what it proves. Avoid decorative console screenshots that add no evidence.
