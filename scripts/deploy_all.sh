#!/usr/bin/env bash
# Deploy kind + Istio + Gatekeeper + sample app for local demos.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=versions.env
source "${ROOT}/scripts/versions.env"

CLUSTER_NAME="${CLUSTER_NAME:-zero-trust}"
ISTIO_DIR="${ROOT}/istio-${ISTIO_VERSION}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required tool: $1" >&2
    exit 1
  }
}

need docker
need curl
need kubectl
need helm

if ! command -v kind >/dev/null 2>&1; then
  echo "Installing kind ${KIND_VERSION}..."
  curl -fsSL -o /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  chmod +x /tmp/kind
  sudo mv /tmp/kind /usr/local/bin/kind
fi

if [[ ! -x "${ISTIO_DIR}/bin/istioctl" ]]; then
  echo "Downloading Istio ${ISTIO_VERSION}..."
  curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" TARGET_ARCH=x86_64 sh -
fi
export PATH="${ISTIO_DIR}/bin:${PATH}"

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config "${ROOT}/manifests/kind/cluster.yaml"
else
  echo "kind cluster ${CLUSTER_NAME} already exists"
fi
kubectl cluster-info

istioctl install --set profile=demo -y
kubectl apply -f "${ROOT}/manifests/namespace.yaml"
kubectl apply -f "${ROOT}/manifests/istio/istio-injection-label.yaml"

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --version "${GATEKEEPER_CHART_VERSION}" \
  --wait \
  --timeout 5m

kubectl apply -f "${ROOT}/manifests/app/"
kubectl apply -f "${ROOT}/manifests/istio/"
kubectl apply -f "${ROOT}/policies/templates/"
kubectl apply -f "${ROOT}/policies/constraints/"

kubectl -n frontend wait --for=condition=available --timeout=300s deployment/frontend
kubectl -n backend wait --for=condition=available --timeout=300s deployment/backend

echo "Deploy complete. Run scripts/test_policy.sh to verify allow/deny."
