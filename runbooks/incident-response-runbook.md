# Incident Response Runbook
## AWS Secure EKS Platform

**Portfolio Position 5 of 6 | Owner: Cloud Security + Platform Engineering**

---

## P1: Compromised Pod / Container Escape

**Trigger:** Falco `CRITICAL` alert — shell spawned in container, `/etc/shadow` read, unexpected outbound connection to malicious IP.

### Step 1 — Identify the pod

```bash
# From Falco alert — extract pod name and namespace
POD_NAME="<from-falco-alert>"
NAMESPACE="<from-falco-alert>"
NODE_NAME=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.nodeName}')
echo "Affected node: ${NODE_NAME}"
```

### Step 2 — Isolate the pod (network quarantine)

```bash
# Apply deny-all network policy to isolate the pod
kubectl label pod "${POD_NAME}" -n "${NAMESPACE}" \
  quarantine=true --overwrite

cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  podSelector:
    matchLabels:
      quarantine: "true"
  policyTypes: [Ingress, Egress]
EOF
echo "Pod ${POD_NAME} network-isolated"
```

### Step 3 — Capture forensic evidence

```bash
# Capture pod spec
kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o yaml > \
  /tmp/forensic-pod-${POD_NAME}.yaml

# Capture recent logs
kubectl logs "${POD_NAME}" -n "${NAMESPACE}" --previous 2>/dev/null > \
  /tmp/forensic-logs-${POD_NAME}.txt || \
kubectl logs "${POD_NAME}" -n "${NAMESPACE}" > \
  /tmp/forensic-logs-${POD_NAME}.txt

# Capture events
kubectl describe pod "${POD_NAME}" -n "${NAMESPACE}" > \
  /tmp/forensic-events-${POD_NAME}.txt

# Upload to SOC bucket
aws s3 cp /tmp/forensic-pod-${POD_NAME}.yaml \
  "s3://<soc-bucket>/incidents/eks/$(date +%Y%m%d)/" --sse aws:kms
aws s3 cp /tmp/forensic-logs-${POD_NAME}.txt \
  "s3://<soc-bucket>/incidents/eks/$(date +%Y%m%d)/" --sse aws:kms
```

### Step 4 — Cordon the node (if host compromise suspected)

```bash
kubectl cordon "${NODE_NAME}"
echo "Node ${NODE_NAME} cordoned — no new pods will schedule"

# Create forensic EBS snapshot of node volumes (from EC2)
INSTANCE_ID=$(kubectl get node "${NODE_NAME}" \
  -o jsonpath='{.spec.providerID}' | cut -d'/' -f5)
for VOL in $(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' \
  --output text --region "${REGION}"); do
  aws ec2 create-snapshot --volume-id "${VOL}" \
    --description "FORENSIC-$(date +%Y%m%d)-${INSTANCE_ID}" \
    --region "${REGION}"
  echo "Forensic snapshot created for volume ${VOL}"
done
```

### Step 5 — Terminate and replace the node

```bash
# Drain remaining pods
kubectl drain "${NODE_NAME}" --ignore-daemonsets \
  --delete-emptydir-data --grace-period=30

# Terminate the instance (ASG will replace it)
aws ec2 terminate-instances \
  --instance-ids "${INSTANCE_ID}" \
  --region "${REGION}"
```

---

## P2: Privileged Pod Detected (PSS Violation Bypassed)

```bash
# Find privileged pods
kubectl get pods --all-namespaces -o json | \
  python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
  for c in pod['spec'].get('containers', []):
    sc = c.get('securityContext', {})
    if sc.get('privileged') or not sc.get('runAsNonRoot'):
      print(f\"{pod['metadata']['namespace']}/{pod['metadata']['name']}: {c['name']}\")
"

# Delete violating pod immediately
kubectl delete pod "<POD_NAME>" -n "<NAMESPACE>" --grace-period=0

# Find the workload that spawned it
kubectl get deployment,daemonset,statefulset --all-namespaces | \
  grep "<workload-name>"
```

---

## P2: GuardDuty EKS Finding

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --query 'DetectorIds[0]' --output text --region "${REGION}")

# Get EKS-related findings
aws guardduty list-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-criteria '{
    "Criterion": {
      "resource.resourceType": {"Eq": ["EKSCluster"]},
      "severity": {"Gte": 7}
    }
  }' --region "${REGION}"

# Get finding details
aws guardduty get-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids "<FINDING_ID>" \
  --region "${REGION}" | \
  python3 -m json.tool | grep -A 5 '"type"\|"description"\|"action"'
```

---

## P3: Certificate / OIDC Issue

```bash
# Verify OIDC provider
aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.identity.oidc.issuer' \
  --region "${REGION}" --output text

# Verify token projection working
kubectl create token test-sa --namespace default --duration 1h 2>/dev/null || \
  echo "Token projection issue detected"

# Check IRSA annotation on service account
kubectl describe serviceaccount aws-load-balancer-controller \
  -n kube-system | grep "eks.amazonaws.com/role-arn"
```

*Owner: Platform Engineering + Cloud Security | Review: Quarterly*
