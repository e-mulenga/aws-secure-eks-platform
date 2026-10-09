# Service Selection Rationale
## AWS Secure EKS Platform

---

## Amazon EKS (Elastic Kubernetes Service)

### Why Selected
EKS is the AWS-managed Kubernetes service that offloads control plane management — etcd, API server, scheduler, controller-manager — to AWS with a 99.9% SLA. This frees the platform team to focus on node security, workload policies, and developer experience rather than Kubernetes infrastructure operations.

### Problem It Solves
- **Business:** Enables container-based workloads at enterprise scale without managing Kubernetes infrastructure.
- **Technical:** Eliminates etcd backup/restore, control plane HA, certificate rotation, and upgrade complexity from the platform team's operational burden.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| Self-managed Kubernetes (kOps/kubeadm) | Full etcd + control plane operational burden; patching, HA, certificates all self-managed |
| Amazon ECS (Fargate) | Not Kubernetes-compatible; cannot use Helm ecosystem; no CNCF portability |
| Google GKE / Azure AKS | Cloud lock-in incompatible with AWS-native security stack (GuardDuty, Security Hub, IAM) |

### Security Controls in This Repo
- **Private API endpoint** — `endpoint_public_access = false` in production; cluster API unreachable from internet
- **KMS envelope encryption** — all Kubernetes Secrets encrypted with a customer-managed KMS key
- **All 5 control plane log types** — api, audit, authenticator, controllerManager, scheduler logged to CloudWatch
- **Access Config: API_AND_CONFIG_MAP** — supports both modern EKS access entries and legacy aws-auth configmap

### Well-Architected Alignment
- **Security:** Private endpoint, KMS encryption, audit logging
- **Reliability:** Managed control plane with 99.9% SLA; multi-AZ by default
- **Operational Excellence:** AWS manages patches, upgrades, scaling of control plane

### Enterprise Use Case
Financial services firms use EKS to run containerised microservices with strict network isolation — each business unit in its own namespace with Pod Security Standards enforced, IRSA limiting each workload to only the AWS APIs it needs, and GuardDuty monitoring EKS audit logs for anomalous kubectl commands or API calls.

---

## EKS Managed Node Groups with Custom Launch Templates

### Why Selected
Managed node groups offload the undifferentiated work of patching, draining, and replacing nodes during upgrades. The custom launch template adds security hardening that the default managed node group configuration does not enforce: IMDSv2, KMS-encrypted EBS, and no public IP assignment.

### IMDSv2 — Why It Matters
The EC2 instance metadata service (IMDS) provides credentials to anything running on the node. IMDSv1 allows any process — including compromised containers — to make an unauthenticated request to `http://169.254.169.254` and retrieve the node's IAM role credentials. IMDSv2 requires a pre-flight PUT request to get a session token, and the launch template limits `hop_limit = 1`, which means the token cannot be relayed by a container escaping to the underlying host.

```hcl
metadata_options {
  http_tokens                 = "required"   # IMDSv2
  http_put_response_hop_limit = 1            # Blocks container relay
}
```

### Well-Architected Alignment
- **Security:** IMDSv2 blocks SSRF-based credential theft; KMS EBS encryption at rest
- **Cost Optimization:** `ON_DEMAND` for general; Spot capacity_type option for compute-intensive
- **Reliability:** Max 25% unavailable during updates; multi-AZ node placement

---

## IRSA — IAM Roles for Service Accounts

### Why Selected
IRSA is the AWS-native mechanism for granting Kubernetes pods access to AWS APIs without sharing node-level IAM credentials. Each pod's service account is annotated with an IAM role ARN; EKS injects a projected service account token; and the AWS SDK exchanges the token for short-lived STS credentials.

### Problem It Solves
Without IRSA, all pods on a node share the node's IAM instance profile. A compromised pod could call any AWS API that the node role permits. IRSA scopes credentials to the pod level — and further restricts them to a specific Kubernetes namespace and service account name via the OIDC condition:

```json
"Condition": {
  "StringEquals": {
    "oidc.eks.region.amazonaws.com/id/CLUSTER:sub":
      "system:serviceaccount:kube-system:aws-load-balancer-controller"
  }
}
```

This means a compromised pod in the `app` namespace cannot use the `kube-system:aws-load-balancer-controller` role even if it finds the token path.

### IRSA Roles Provisioned
| Role | Namespace | Service Account | AWS Permissions |
|---|---|---|---|
| ALB Controller | kube-system | aws-load-balancer-controller | ELB, EC2, WAFv2, ACM |
| Cluster Autoscaler | kube-system | cluster-autoscaler | AutoScaling (tag-conditioned) |
| External Secrets | external-secrets | external-secrets | Secrets Manager, SSM, KMS |
| EBS CSI Driver | kube-system | ebs-csi-controller-sa | EC2 volumes, KMS |
| Container Insights | amazon-cloudwatch | cloudwatch-agent | CloudWatch logs and metrics |

### Well-Architected Alignment
- **Security:** Pod-level credential isolation; no node-level shared credentials
- **Operational Excellence:** Credential rotation handled by STS; no secret rotation burden

---

## AWS Load Balancer Controller

### Why Selected
The AWS Load Balancer Controller provisions Application Load Balancers for Kubernetes Ingress resources, integrating native AWS features unavailable in the open-source nginx ingress: WAFv2 association, ACM certificate management, Shield Advanced protection, and target group health checks aligned with EKS pod readiness.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| nginx Ingress Controller | No native WAFv2 or ACM integration; requires NLB or NodePort for AWS |
| Traefik | Excellent but adds another CRD/config layer; no native ALB provisioning |
| AWS ALB directly | Cannot respond to Kubernetes Ingress changes; no automation |

### Well-Architected Alignment
- **Security:** WAFv2 CRS rules on all ALBs; TLS 1.3 termination; Shield integration
- **Reliability:** Multi-AZ ALB with health checks; automatic deregistration on pod termination

---

## External Secrets Operator

### Why Selected
External Secrets Operator (ESO) synchronises secrets from AWS Secrets Manager and SSM Parameter Store into Kubernetes Secret objects. Application pods read Kubernetes Secrets normally — they never need AWS API credentials or knowledge of Secrets Manager. ESO uses IRSA for AWS access and refreshes secrets on a configurable interval.

### Problem It Solves
Without ESO, teams either store secrets in Kubernetes directly (no rotation, no audit) or write custom init containers to pull from Secrets Manager (no standardisation). ESO provides a single, auditable secrets synchronisation mechanism across all namespaces.

### Well-Architected Alignment
- **Security:** Secrets never committed to git; rotation propagates automatically to pods
- **Operational Excellence:** Teams define `ExternalSecret` CRDs; platform manages the sync

---

## Falco (Runtime Security)

### Why Selected
Falco monitors system calls from running containers and generates alerts when behaviour deviates from expected patterns: a container spawning a shell, reading `/etc/passwd`, making unexpected network connections, or writing to `/etc`. This detects compromised containers that have already bypassed admission controls and Pod Security Standards.

### Problem It Solves
Admission controls (Pod Security Standards, OPA) check pod configuration at deploy time. They cannot detect what happens at runtime — a container that starts legitimately but is later exploited. Falco fills this gap with eBPF-based syscall monitoring that does not require modifying application code.

### Integration with SOC
Falco Sidekick forwards findings to the SOC's SNS `critical-alerts` topic (provisioned by `aws-cloud-security-operations-center`), where they appear alongside GuardDuty and Security Hub findings in the SOC dashboard.

### Well-Architected Alignment
- **Security:** Runtime threat detection complementing preventive admission controls
- **Operational Excellence:** eBPF driver requires no kernel module; zero application code changes

---

## GuardDuty EKS Audit Log Monitoring

### Why Selected
GuardDuty EKS Audit Log Monitoring analyses the Kubernetes control plane audit log stream using ML models trained on EKS-specific attack patterns: API calls from unexpected principals, creation of high-privilege pods, RBAC escalation attempts, and cryptomining detection via EKS workload anomalies.

### Problem It Solves
CloudWatch stores the audit log but does not analyse it. Manually reviewing thousands of audit log events per hour for anomalies is impractical. GuardDuty's ML baseline detects deviation from normal cluster behaviour within minutes.

### Well-Architected Alignment
- **Security:** ML-based Kubernetes threat detection; feeds SOC Security Hub aggregator
- **Cost Optimization:** Volume-based pricing on audit log data; no cluster-side compute

---

## Pod Security Standards (Restricted)

### Why Selected
Pod Security Standards (PSS) are built into Kubernetes 1.25+ as the successor to PodSecurityPolicy. The `restricted` profile enforces the strongest security posture: no privileged containers, no root execution, read-only root filesystem, all capabilities dropped, and seccomp `RuntimeDefault`. Enforcement is implemented via namespace labels — no webhook infrastructure required.

### What `restricted` Enforces
| Requirement | Enforcement |
|---|---|
| `runAsNonRoot: true` | Must be set in pod or container securityContext |
| `allowPrivilegeEscalation: false` | Hardcoded — no override |
| `capabilities.drop: [ALL]` | All Linux capabilities dropped |
| `seccompProfile: RuntimeDefault` | System call filtering enabled |
| No `hostPID`, `hostIPC`, `hostNetwork` | Blocked |
| No `hostPath` volumes | Blocked |

### Well-Architected Alignment
- **Security:** Prevents container escape via privilege escalation and host namespace access
- **Operational Excellence:** Built-in Kubernetes feature; no webhook to maintain

---

## CloudWatch Container Insights

### Why Selected
Container Insights provides cluster, node, pod, and container-level metrics in CloudWatch without deploying Prometheus or a commercial monitoring stack. It uses the CloudWatch agent as a DaemonSet (deployed via IRSA) and integrates natively with CloudWatch alarms and dashboards provisioned by this platform.

### Metrics Collected
- Node: CPU, memory, network, disk utilisation
- Pod: CPU, memory, network I/O, restart count
- Container: CPU, memory, filesystem

### Well-Architected Alignment
- **Operational Excellence:** No external monitoring infrastructure; metrics in the same AWS console as all other platform services
- **Cost Optimization:** Pay per metric; no Prometheus/Grafana infrastructure cost

---

*Owner: Platform Engineering | Review: Quarterly*
