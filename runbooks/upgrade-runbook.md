# EKS Cluster Upgrade Runbook
## AWS Secure EKS Platform

**Portfolio Position 5 of 6 | Owner: Platform Engineering**

---

## Upgrade Strategy

```
1. Upgrade control plane → 2. Upgrade add-ons → 3. Upgrade node groups
```

**Never skip Kubernetes minor versions.** 1.27 → 1.28 → 1.29, not 1.27 → 1.29.

---

## Pre-Upgrade Checklist

```bash
CLUSTER="${ORG}-${ENV}-platform"
CURRENT=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.version' --output text --region "${REGION}")
TARGET="1.30"  # set target version

echo "Current: ${CURRENT} → Target: ${TARGET}"

# 1. Check deprecated API usage
kubectl api-resources --verbs=list 2>/dev/null | head -20

# 2. Check cluster add-on versions
aws eks describe-addon-versions \
  --kubernetes-version "${TARGET}" \
  --query 'addons[*].{Name:addonName,Latest:addonVersions[0].addonVersion}' \
  --output table --region "${REGION}"

# 3. Verify no pods in Terminating state
kubectl get pods --all-namespaces | grep Terminating

# 4. Verify PodDisruptionBudgets will permit upgrades
kubectl get pdb --all-namespaces

# 5. Backup ETCD (via EKS — create a cluster snapshot note)
echo "EKS manages etcd backup. Snapshot current state by noting:"
echo "  Cluster: ${CLUSTER} | Version: ${CURRENT} | Date: $(date -u)"
```

---

## Step 1: Upgrade Control Plane

```bash
aws eks update-cluster-version \
  --name "${CLUSTER}" \
  --kubernetes-version "${TARGET}" \
  --region "${REGION}"

# Wait for upgrade (takes 10-20 minutes)
aws eks wait cluster-active --name "${CLUSTER}" --region "${REGION}"

# Verify
aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.version' --output text --region "${REGION}"
```

---

## Step 2: Upgrade EKS Add-ons

```bash
# Get current addon versions
aws eks list-addons --cluster-name "${CLUSTER}" --region "${REGION}"

# Upgrade each addon
for ADDON in coredns kube-proxy vpc-cni aws-ebs-csi-driver; do
  LATEST=$(aws eks describe-addon-versions \
    --kubernetes-version "${TARGET}" \
    --addon-name "${ADDON}" \
    --query 'addons[0].addonVersions[0].addonVersion' \
    --output text --region "${REGION}")

  echo "Upgrading ${ADDON} to ${LATEST}"
  aws eks update-addon \
    --cluster-name "${CLUSTER}" \
    --addon-name "${ADDON}" \
    --addon-version "${LATEST}" \
    --resolve-conflicts OVERWRITE \
    --region "${REGION}"

  aws eks wait addon-active \
    --cluster-name "${CLUSTER}" \
    --addon-name "${ADDON}" \
    --region "${REGION}"
  echo "✓ ${ADDON} upgraded"
done
```

---

## Step 3: Upgrade Node Groups (Rolling)

```bash
# Upgrade node group — AWS performs rolling replacement
for NG in $(aws eks list-nodegroups \
  --cluster-name "${CLUSTER}" \
  --query 'nodegroups[]' --output text --region "${REGION}"); do

  echo "Upgrading node group: ${NG}"
  aws eks update-nodegroup-version \
    --cluster-name "${CLUSTER}" \
    --nodegroup-name "${NG}" \
    --region "${REGION}"

  # Wait for upgrade (can take 15-30 min per group)
  aws eks wait nodegroup-active \
    --cluster-name "${CLUSTER}" \
    --nodegroup-name "${NG}" \
    --region "${REGION}"

  echo "✓ Node group ${NG} upgraded"
  kubectl get nodes | grep -v "master"
done
```

---

## Post-Upgrade Validation

```bash
# Run full validation
ENV="${ENV}" ORG="${ORG}" AWS_REGION="${REGION}" \
  bash validation/validate-eks.sh

# Verify all pods are healthy
kubectl get pods --all-namespaces | grep -v "Running\|Completed" | \
  grep -v "^NAMESPACE"

# Verify Helm add-ons still running
for RELEASE in aws-load-balancer-controller cluster-autoscaler \
               metrics-server external-secrets falco; do
  STATUS=$(helm status "${RELEASE}" -n kube-system 2>/dev/null || \
           helm status "${RELEASE}" -n external-secrets 2>/dev/null || \
           helm status "${RELEASE}" -n falco 2>/dev/null || \
           echo "NOT_FOUND")
  echo "${RELEASE}: ${STATUS}"
done

# Apply Terraform to pin new versions in state
terraform apply -var-file="environments/${ENV}/terraform.tfvars" \
  -target=module.eks_cluster
```

*Owner: Platform Engineering | Review: Before every upgrade cycle*
