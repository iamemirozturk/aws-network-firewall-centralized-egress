# Deployment guide

## 1. Choose a disposable test account

Start in a non-production AWS account. Confirm the account and caller before every plan or apply:

```bash
aws sts get-caller-identity
```

## 2. Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Review the region, AZs, inspection CIDR, non-overlapping spoke CIDRs, allowed domains, retention period, and tags. Keep TLS inspection disabled for the first deployment.

## 3. Validate locally

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
```

Review every route in the plan. In particular, verify that NAT route tables send spoke CIDRs to firewall endpoint IDs and firewall route tables send spoke CIDRs to Transit Gateway.

## 4. Apply

```bash
terraform apply tfplan
```

Record the Terraform and provider versions, region, date, apply summary, and any deviations. Do not publish account IDs, public IPs, internal names, or customer data.

## 5. Create a test workload

The Terraform creates networking but not an EC2 test instance. Launch a private instance through your normal hardened pattern, preferably managed with Systems Manager Session Manager and no public IP. Ensure DNS resolution and required Systems Manager endpoints or controlled egress are available.

## 6. Validate and remove

Complete `validation.md`, capture sanitized evidence, and then destroy the lab when it is no longer needed:

```bash
terraform plan -destroy
terraform apply -var='enable_firewall_protections=false'
cd ..
TF_VAR_enable_firewall_protections=false ./scripts/destroy.sh
```

The separate apply disables Network Firewall deletion and configuration-change protections. Review that plan carefully and use it only for an authorized cleanup. The cleanup script requires an explicit environment acknowledgement, displays the AWS account and Terraform workspace, creates a saved destroy plan, and requires an exact confirmation phrase. It never disables protections automatically.
