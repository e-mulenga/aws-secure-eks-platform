# Contributing Guide — AWS Secure EKS Platform

**Portfolio Position 5 of 6** — Changes affect `multi-cloud-governance` downstream.

## Standards

- `provider.tf` contains `terraform {}` block — **no** `versions.tf`
- All action versions pinned to Node.js 24-compatible releases (see `.github/workflows/`)
- `tfsec` runs as direct binary — never use `tfsec-sarif-action@v1`
- No hardcoded values: cluster names, account IDs, regions, secrets
- IMDSv2 and KMS encryption enforced in every node group launch template
- Pod Security Standards must be `restricted` — never lower without Security Architect sign-off
- All new IRSA roles: namespace + service account scoped OIDC conditions (no wildcard `*`)

## Node.js 24 Compliance

All GitHub Actions in this repo use pinned, Node.js 24-compatible versions:
- `actions/checkout@v4.2.2`
- `aws-actions/configure-aws-credentials@v4.1.0`
- `hashicorp/setup-terraform@v3.1.2`
- `github/codeql-action/upload-sarif@v3.29.5`
- `tfsec` direct binary (replaces deprecated `tfsec-sarif-action@v1`)

## Adding a New Node Group

1. Add the group to the `node_groups` variable in `variables.tf`
2. Add environment-specific sizing in `environments/<env>/terraform.tfvars`
3. Verify the launch template enforces IMDSv2 and KMS EBS encryption
4. Tag with `k8s.io/cluster-autoscaler/enabled = true`
5. Run: `bash validation/validate-eks.sh`
