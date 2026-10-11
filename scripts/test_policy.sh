#!/usr/bin/env bash
# Assert zero-trust controls: mTLS STRICT, Istio AuthZ, OPA ext_authz, Gatekeeper, egress.
# Failures are not masked — every assertion exits non-zero on mismatch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_URL="http://backend.backend.svc.cluster.local"
DB_URL="http://db.db.svc.cluster.local/"
CURL_IMAGE="curlimages/curl:8.12.1"
BAD_DEPLOY_FIXTURE="${ROOT}/manifests/fixtures/bad-deployment-no-app-label.yaml"

echo "Waiting for deployments..."
kubectl -n frontend wait --for=condition=available --timeout=180s deployment/frontend
kubectl -n backend wait --for=condition=available --timeout=180s deployment/backend
kubectl -n db wait --for=condition=available --timeout=180s deployment/db
kubectl -n istio-system wait --for=condition=available --timeout=180s deployment/opa

ensure_client() {
  local ns="$1"
  local name="$2"
  local sa="$3"
  if kubectl -n "${ns}" get pod "${name}" >/dev/null 2>&1; then
    kubectl -n "${ns}" delete pod "${name}" --wait=true --timeout=60s
  fi
  kubectl -n "${ns}" run "${name}" \
    --image="${CURL_IMAGE}" \
    --restart=Never \
    --labels="app=${name}" \
    --overrides="$(printf '{"spec":{"serviceAccountName":"%s"}}' "${sa}")" \
    --command -- sleep 3600
  kubectl -n "${ns}" wait --for=condition=Ready --timeout=180s "pod/${name}"
}

client_container() {
  local ns="$1"
  local pod="$2"
  # Prefer the workload container (same name as the pod from kubectl run).
  if kubectl -n "${ns}" get pod "${pod}" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n' | grep -qx "${pod}"; then
    echo "${pod}"
    return
  fi
  kubectl -n "${ns}" get pod "${pod}" -o jsonpath='{.spec.containers[0].name}'
}

http_code() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local container
  container="$(client_container "${ns}" "${pod}")"
  kubectl -n "${ns}" exec "${pod}" -c "${container}" -- \
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "${url}" 2>/dev/null || echo "000"
}

wait_for_code() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local expected="$4"
  local label="$5"
  local code=""
  for attempt in $(seq 1 36); do
    code="$(http_code "${ns}" "${pod}" "${url}")"
    echo "${label} attempt ${attempt}: HTTP ${code}"
    if [[ "${code}" == "${expected}" ]]; then
      echo "PASS: ${label} returned ${expected}"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: ${label} expected HTTP ${expected}, last status ${code}" >&2
  local container
  container="$(client_container "${ns}" "${pod}")"
  kubectl -n "${ns}" exec "${pod}" -c "${container}" -- curl -sv --max-time 15 "${url}" >&2 || true
  kubectl -n istio-system logs deploy/opa --tail=40 >&2 || true
  return 1
}

assert_not_code() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local forbidden="$4"
  local label="$5"
  local code=""
  for attempt in $(seq 1 18); do
    code="$(http_code "${ns}" "${pod}" "${url}")"
    echo "${label} attempt ${attempt}: HTTP ${code}"
    if [[ "${code}" != "${forbidden}" && "${code}" != "" ]]; then
      echo "PASS: ${label} did not return ${forbidden} (got ${code})"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: ${label} unexpectedly returned ${forbidden}" >&2
  return 1
}

# --- Clients with dedicated ServiceAccounts (match AuthorizationPolicy principals) ---
ensure_client frontend auth-client frontend
ensure_client backend backend-client backend
ensure_client db unauth-client db

echo "=== Test 1: authorized frontend -> backend / (expect HTTP 200) ==="
wait_for_code frontend auth-client "${BACKEND_URL}/" 200 "authorized-root"

echo "=== Test 2: unauthorized db principal -> backend (expect HTTP 403) ==="
wait_for_code db unauth-client "${BACKEND_URL}/" 403 "unauthorized-principal"

echo "=== Test 3: OPA denies /admin for allowed principal (expect HTTP 403) ==="
wait_for_code frontend auth-client "${BACKEND_URL}/admin" 403 "opa-deny-admin"

echo "=== Test 4: backend -> db allowed (expect HTTP 200) ==="
wait_for_code backend backend-client "${DB_URL}" 200 "backend-to-db"

echo "=== Test 5: frontend -> db denied (expect HTTP 403) ==="
wait_for_code frontend auth-client "${DB_URL}" 403 "frontend-to-db"

echo "=== Test 6: STRICT mTLS — plaintext from non-mesh namespace rejected ==="
kubectl get ns plaintext >/dev/null 2>&1 || kubectl create namespace plaintext
if kubectl -n plaintext get pod plain-client >/dev/null 2>&1; then
  kubectl -n plaintext delete pod plain-client --wait=true --timeout=60s
fi
kubectl -n plaintext run plain-client \
  --image="${CURL_IMAGE}" \
  --restart=Never \
  --labels="app=plain-client" \
  --command -- sleep 3600
kubectl -n plaintext wait --for=condition=Ready --timeout=180s pod/plain-client
assert_not_code plaintext plain-client "${BACKEND_URL}/" 200 "plaintext-mtls"

echo "=== Test 7: Gatekeeper denies Deployment without app label ==="
set +e
gk_out="$(kubectl apply --dry-run=server -f "${BAD_DEPLOY_FIXTURE}" 2>&1)"
gk_rc=$?
set -e
echo "${gk_out}"
if [[ "${gk_rc}" -eq 0 ]]; then
  echo "FAIL: Gatekeeper accepted unlabeled Deployment" >&2
  exit 1
fi
if ! grep -Eqi 'denied|violation|failed|forbidden|admit' <<<"${gk_out}"; then
  echo "FAIL: Gatekeeper rejection output missing deny signal" >&2
  exit 1
fi
echo "PASS: Gatekeeper denied unlabeled Deployment"

echo "=== Test 8: egress to non-allowlisted host blocked (REGISTRY_ONLY) ==="
# example.com is not in the ServiceEntry allowlist; REGISTRY_ONLY must block it.
egress_code="$(http_code frontend auth-client "https://example.com/")"
echo "egress example.com HTTP ${egress_code}"
if [[ "${egress_code}" == "200" ]]; then
  echo "FAIL: egress to example.com unexpectedly succeeded" >&2
  exit 1
fi
echo "PASS: egress to non-allowlisted host blocked (HTTP ${egress_code})"

echo "All policy checks passed."
