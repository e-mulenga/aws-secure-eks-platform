#!/usr/bin/env bash
# Post-deploy EKS platform validation
# Usage: ENV=prod ORG=acme AWS_REGION=af-south-1 bash validation/validate-eks.sh
set -euo pipefail
: "${ENV:?Required}"; : "${ORG:?Required}"; : "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"
PASS=0; FAIL=0; WARN=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
CLUSTER="${ORG}-${ENV}-platform"

echo "==========================================="
echo " EKS Platform Validation | ${CLUSTER}"
echo "==========================================="

# 1. Cluster active
echo -e "\n--- EKS Cluster ---"
STATUS=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.status' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NOT_FOUND")
[[ "${STATUS}" == "ACTIVE" ]] && pass "Cluster ACTIVE: ${CLUSTER}" || fail "Cluster NOT ACTIVE: ${STATUS}"

# 2. Private endpoint only
PRIV=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.resourcesVpcConfig.endpointPrivateAccess' --output text --region "${AWS_REGION}" 2>/dev/null || echo "false")
PUB=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text --region "${AWS_REGION}" 2>/dev/null || echo "true")
[[ "${PRIV}" == "True" ]] && pass "Private endpoint enabled" || fail "Private endpoint NOT enabled"
[[ "${ENV}" == "prod" && "${PUB}" == "True" ]] && fail "PUBLIC endpoint enabled in PROD — security risk!" || \
  [[ "${ENV}" != "prod" ]] && warn "Public endpoint: ${PUB} (acceptable in ${ENV})" || pass "Public endpoint disabled in prod"

# 3. KMS encryption
KMS=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.encryptionConfig[0].provider.keyArn' --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
[[ -n "${KMS}" && "${KMS}" != "None" ]] && pass "KMS secrets encryption: ${KMS:0:50}..." || fail "KMS encryption NOT configured"

# 4. Node groups
echo -e "\n--- Node Groups ---"
NG_COUNT=$(aws eks list-nodegroups --cluster-name "${CLUSTER}" --query 'length(nodegroups)' --output text --region "${AWS_REGION}" 2>/dev/null || echo 0)
[[ "${NG_COUNT}" -ge 1 ]] && pass "Node groups: ${NG_COUNT}" || fail "No node groups found"

for NG in $(aws eks list-nodegroups --cluster-name "${CLUSTER}" --query 'nodegroups[]' --output text --region "${AWS_REGION}" 2>/dev/null); do
  NG_STATUS=$(aws eks describe-nodegroup --cluster-name "${CLUSTER}" --nodegroup-name "${NG}" --query 'nodegroup.status' --output text --region "${AWS_REGION}" 2>/dev/null || echo "UNKNOWN")
  [[ "${NG_STATUS}" == "ACTIVE" ]] && pass "Node group ACTIVE: ${NG}" || fail "Node group ${NG}: ${NG_STATUS}"
done

# 5. OIDC provider
echo -e "\n--- Security ---"
OIDC=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.identity.oidc.issuer' --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
[[ -n "${OIDC}" ]] && pass "OIDC provider configured" || fail "OIDC provider NOT found"

# 6. GuardDuty EKS protection
GD_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
if [[ -n "${GD_ID}" && "${GD_ID}" != "None" ]]; then
  K8S=$(aws guardduty get-detector --detector-id "${GD_ID}" --query 'Features[?Name==`EKS_AUDIT_LOGS`].Status' --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
  [[ "${K8S}" == "ENABLED" ]] && pass "GuardDuty EKS audit logs enabled" || warn "GuardDuty EKS audit logs not confirmed"
else
  warn "GuardDuty detector not found"
fi

# 7. Control plane logs
echo -e "\n--- Logging ---"
LOGS=$(aws eks describe-cluster --name "${CLUSTER}" --query 'cluster.logging.clusterLogging[?enabled==`true`].types' --output json --region "${AWS_REGION}" 2>/dev/null || echo "[]")
LOG_COUNT=$(echo "${LOGS}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(len(t) for t in d))" 2>/dev/null || echo 0)
[[ "${LOG_COUNT}" -ge 5 ]] && pass "All 5 control plane log types enabled" || fail "Only ${LOG_COUNT}/5 log types enabled"

# 8. kubectl connectivity (optional — requires kubeconfig)
echo -e "\n--- Kubernetes ---"
if command -v kubectl >/dev/null 2>&1; then
  aws eks update-kubeconfig --name "${CLUSTER}" --region "${AWS_REGION}" --alias "validation-${CLUSTER}" &>/dev/null
  NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo 0)
  [[ "${NODES}" -ge 1 ]] && pass "kubectl: ${NODES} node(s) Ready" || fail "kubectl: no nodes found"
  
  for NS in app data monitoring security; do
    NS_EXISTS=$(kubectl get namespace "${NS}" --no-headers 2>/dev/null | wc -l || echo 0)
    [[ "${NS_EXISTS}" -ge 1 ]] && pass "Namespace exists: ${NS}" || warn "Namespace not found: ${NS}"
  done
  
  # Check pod security labels
  RESTRICTED_NS=$(kubectl get namespaces -l "pod-security.kubernetes.io/enforce=restricted" --no-headers 2>/dev/null | wc -l || echo 0)
  [[ "${RESTRICTED_NS}" -ge 4 ]] && pass "Pod Security Standards enforced on ${RESTRICTED_NS} namespace(s)" || warn "Pod Security Standards: ${RESTRICTED_NS} namespaces (expected ≥4)"
else
  warn "kubectl not installed — skipping Kubernetes checks"
fi

echo -e "\n==========================================="
echo " PASS: ${PASS}  WARN: ${WARN}  FAIL: ${FAIL}"
echo "==========================================="
[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
