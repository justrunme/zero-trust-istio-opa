#!/usr/bin/env bash
# Assert Istio AuthorizationPolicy enforce: authorized GET allowed, unauthorized denied (403).
set -euo pipefail

BACKEND_URL="http://backend.backend.svc.cluster.local/"
CURL_IMAGE="curlimages/curl:8.12.1"

echo "Waiting for deployments..."
kubectl -n frontend wait --for=condition=available --timeout=180s deployment/frontend
kubectl -n backend wait --for=condition=available --timeout=180s deployment/backend

ensure_client() {
  local ns="$1"
  local name="$2"
  if ! kubectl -n "${ns}" get pod "${name}" >/dev/null 2>&1; then
    kubectl -n "${ns}" run "${name}" \
      --image="${CURL_IMAGE}" \
      --restart=Never \
      --labels="app=${name}" \
      --command -- sleep 3600
  fi
  kubectl -n "${ns}" wait --for=condition=Ready --timeout=180s "pod/${name}"
}

# Both clients use the namespace default ServiceAccount (matches AuthorizationPolicy principals).
ensure_client frontend auth-client
ensure_client db unauth-client

http_code() {
  local ns="$1"
  local pod="$2"
  kubectl -n "${ns}" exec "${pod}" -c "${pod}" -- \
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "${BACKEND_URL}" || echo "000"
}

wait_for_code() {
  local ns="$1"
  local pod="$2"
  local expected="$3"
  local label="$4"
  local code=""
  for attempt in $(seq 1 30); do
    code="$(http_code "${ns}" "${pod}")"
    echo "${label} attempt ${attempt}: HTTP ${code}"
    if [[ "${code}" == "${expected}" ]]; then
      echo "PASS: ${label} returned ${expected}"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: ${label} expected HTTP ${expected}, last status ${code}" >&2
  kubectl -n "${ns}" exec "${pod}" -c "${pod}" -- curl -sv --max-time 15 "${BACKEND_URL}" >&2 || true
  return 1
}

echo "Test 1: authorized request frontend -> backend (expect HTTP 200)"
wait_for_code frontend auth-client 200 "authorized"

echo "Test 2: unauthorized request db -> backend (expect HTTP 403)"
wait_for_code db unauth-client 403 "unauthorized"

echo "All policy checks passed."
