# Security Policy — AWS Secure EKS Platform

## Reporting Vulnerabilities

**Email:** security@[your-org].com  
**Subject:** `[SECURITY] aws-secure-eks-platform — <description>`

Do NOT open public GitHub issues for security vulnerabilities.

## Security Defaults

| Control | Setting | Configurable? |
|---|---|---|
| EKS private endpoint | `true` | Yes (public only for dev) |
| KMS secrets encryption | Always on | No |
| IMDSv2 on nodes | `required` | No |
| EBS encryption | Always on | No |
| Pod Security Standards | `restricted` | Yes (with sign-off) |
| Default-deny NetworkPolicy | Applied | No |
| OIDC credentials for GitHub Actions | Always | No |
| No privileged containers | Enforced | No |

## Supported Versions

| Branch | Security Fixes |
|---|---|
| `main` | ✅ Yes |
| Feature branches | ❌ Merge first |
