#!/usr/bin/env bash
set -euo pipefail

project="${PROJECT:-egress-inspection}"

echo "Route tables tagged for project: ${project}"
aws ec2 describe-route-tables \
  --filters "Name=tag:Project,Values=${project}" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes}' \
  --output json

echo "Transit Gateway attachments tagged for project: ${project}"
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=tag:Project,Values=${project}" \
  --query 'TransitGatewayVpcAttachments[].{Name:Tags[?Key==`Name`]|[0].Value,State:State,Options:Options}' \
  --output json

echo "Review the result against docs/validation.md; this script reports configuration and does not declare a pass."
