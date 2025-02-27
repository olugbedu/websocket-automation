#!/bin/bash
set -eo pipefail

# Configuration paths
AWS_CONFIG_DIR="/home/backenduser/.kube/aws"
MANUAL_CONFIG_DIR="/home/backenduser/.kube/manual"
AWS_CONFIG="${AWS_CONFIG_DIR}/config"
MANUAL_CONFIG="${MANUAL_CONFIG_DIR}/config"

# Ensure directories exist
mkdir -p "${AWS_CONFIG_DIR}" "${MANUAL_CONFIG_DIR}"

if [ "$KUBECONFIG_MODE" = "aws" ]; then
  echo "Initializing AWS EKS configuration..."
  
  # Validate required AWS variables
  required_vars=(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION KUBE_CLUSTER_NAME)
  for var in "${required_vars[@]}"; do
      if [[ -z "${!var}" ]]; then
          echo "ERROR: Missing required environment variable $var" >&2
          exit 1
      fi
  done
  
  # Clean existing AWS config
  rm -f "${AWS_CONFIG}"
  
  # Configure AWS CLI
  aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
  aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
  aws configure set default.region ${AWS_DEFAULT_REGION}

  # Verify EKS cluster exists
  if ! aws eks describe-cluster --name ${KUBE_CLUSTER_NAME} >/dev/null; then
      echo "ERROR: Failed to access EKS cluster '${KUBE_CLUSTER_NAME}'" >&2
      exit 1
  fi
  
  # Generate fresh config
  aws eks update-kubeconfig \
    --name "${KUBE_CLUSTER_NAME}" \
    --region "${AWS_DEFAULT_REGION}" \
    --kubeconfig "${AWS_CONFIG}"
    
  export KUBECONFIG="${AWS_CONFIG}"

elif [ "$KUBECONFIG_MODE" = "manual" ]; then
  echo "Using manual kubeconfig..."
  
  if [ ! -f "${MANUAL_CONFIG}" ]; then
    echo "ERROR: Manual config not found at ${MANUAL_CONFIG}"
    exit 1
  fi
  
  export KUBECONFIG="${MANUAL_CONFIG}"

else
  echo "ERROR: Invalid KUBECONFIG_MODE '${KUBECONFIG_MODE}'"
  exit 1
fi

# Verify cluster access
if ! kubectl cluster-info --request-timeout=10s; then
  echo "Failed to connect to Kubernetes cluster"
  exit 1
fi

# Verify kubectl version
echo "Kubectl Version:"
kubectl version --client -o json | jq -r '.clientVersion.gitVersion'

exec "$@"
