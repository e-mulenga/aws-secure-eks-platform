# Cluster Operations Runbook
## AWS Secure EKS Platform

**Portfolio Position 5 of 6 | Owner: Platform Engineering**

---

## Daily Operations

### Morning Health Check

```bash
export CLUSTER="${ORG}-${ENV}-platform"
export REGION="af-south-1"

# 1. Cluster and node status
aws eks describe-cluster --name "${CLUSTER}" \
  --query '{Status:status,Version:version,Endpoint:endpoint}' \
  --region "${REGION}" --output table

kubectl get nodes -o wide
kubectl top nodes

# 2. Pod health across all namespaces
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# 3. Pending/failed pods
kubectl get pods --all-namespaces --field-selector status.phase!=Running,status.phase!=Succeeded

# 4. Open SOC EKS dashboard
echo "https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${ORG}-${ENV}-eks-operations"
```

---

## Managing Node Groups

### Scale a Node Group

```bash
NODE_GROUP="${ORG}-${ENV}-general"

# Scale up
aws eks update-nodegroup-config \
  --cluster-name "${CLUSTER}" \
  --nodegroup-name "${NODE_GROUP}" \
  --scaling-config minSize=3,maxSize=10,desiredSize=5 \
  --region "${REGION}"

# Watch scaling progress
watch -n 10 "kubectl get nodes --show-labels | grep ${NODE_GROUP}"
```

### Cordon and Drain a Node (maintenance)

```bash
NODE_NAME="<node-name>"

# Cordon — prevent new pods from scheduling
kubectl cordon "${NODE_NAME}"

# Drain — evict all pods gracefully
kubectl drain "${NODE_NAME}" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# Verify node empty
kubectl get pods --all-namespaces -o wide | grep "${NODE_NAME}"

# After maintenance: uncordon
kubectl uncordon "${NODE_NAME}"
```

---

## Managing Secrets via External Secrets Operator

### Create a new ExternalSecret

```bash
cat << EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
    creationPolicy: Owner
  data:
    - secretKey: db-password
      remoteRef:
        key: "${ORG}/${ENV}/my-app/db-password"
EOF

# Verify sync status
kubectl get externalsecret my-app-secrets -n app
kubectl describe externalsecret my-app-secrets -n app
```

### Verify secret was synced

```bash
kubectl get secret my-app-secrets -n app
kubectl describe secret my-app-secrets -n app | grep -v "^Data"
```

---

## Cluster Autoscaler Operations

### Check autoscaler logs

```bash
kubectl logs -l app.kubernetes.io/name=cluster-autoscaler \
  -n kube-system --tail=50 | grep -E "scale_up|scale_down|node"
```

### Trigger manual scale-up test

```bash
# Deploy a resource-hungry deployment to trigger scale-up
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale-test
  namespace: app
spec:
  replicas: 20
  selector:
    matchLabels:
      app: scale-test
  template:
    metadata:
      labels:
        app: scale-test
    spec:
      containers:
        - name: pause
          image: registry.k8s.io/pause:3.9
          resources:
            requests:
              cpu: "500m"
              memory: "256Mi"
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        seccompProfile:
          type: RuntimeDefault
EOF

# Watch nodes being added
watch kubectl get nodes

# Clean up
kubectl delete deployment scale-test -n app
```

---

## Falco Runtime Security

### View recent Falco alerts

```bash
kubectl logs -l app.kubernetes.io/name=falco \
  -n falco --tail=50 | python3 -c "
import sys, json
for line in sys.stdin:
  try:
    event = json.loads(line)
    if event.get('priority') in ['Critical','Error','Warning']:
      print(f\"{event['time']} [{event['priority']}] {event['output']}\")
  except:
    pass
"
```

### Investigate a Falco alert

```bash
# Get alert details
ALERT_TIME="<timestamp>"
POD_NAME="<pod-from-alert>"
NAMESPACE="<namespace>"

# Check pod security context
kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o yaml | \
  grep -A 20 securityContext

# Check recent pod events
kubectl describe pod "${POD_NAME}" -n "${NAMESPACE}" | tail -20

# Check CloudTrail for API calls from this pod's service account
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue="${POD_NAME}" \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --region "${REGION}"
```

---

## Maintenance Schedule

| Task | Frequency | Owner |
|---|---|---|
| Node group patch (AL2 AMI update) | Monthly | Platform Engineering |
| EKS add-on version updates | Monthly | Platform Engineering |
| Helm chart updates | Monthly | Platform Engineering |
| Cluster version upgrade | Quarterly | Platform Engineering |
| IRSA role policy review | Quarterly | Cloud Security |
| Pod Security Standards audit | Quarterly | Cloud Security |
| Falco rules review | Quarterly | Cloud Security |
| DR failover test | Bi-annually | Platform Engineering |

*Owner: Platform Engineering | Review: Quarterly*
