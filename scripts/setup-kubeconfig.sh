#!/usr/bin/env bash
# Configure kubectl access to the EKS cluster
# Usage: ENV=prod ORG=acme AWS_REGION=af-south-1 bash scripts/setup-kubeconfig.sh
set -euo pipefail
: "${ENV:?Required}"; : "${ORG:?Required}"; : "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "${ORG}-${ENV}-platform")
echo "Configuring kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --alias "${ORG}-${ENV}-eks"
echo "[✓] kubeconfig updated — context: ${ORG}-${ENV}-eks"
kubectl cluster-info
kubectl get nodes -o wide
