#!/usr/bin/env bash
# Assert zero-trust controls: mTLS STRICT, Istio AuthZ, OPA ext_authz, Gatekeeper, egress.
# Failures are not masked — every assertion exits non-zero on mismatch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/http_probe_classify.sh
source "${ROOT}/scripts/lib/http_probe_classify.sh"

BACKEND_URL="http://backend.backend.svc.cluster.local"
DB_URL="http://db.db.svc.cluster.local/"
ALLOWED_EGRESS_URL="https://httpbin.org/get"
# HTTP (not HTTPS): REGISTRY_ONLY answers unknown HTTP hosts with an explicit
# Envoy 502 from BlackHoleCluster. HTTPS to a missing ServiceEntry often surfaces
# only as curl exit 35 (TLS error), which is not an accepted egress PASS signal.
DENIED_EGRESS_URL="http://example.com/"
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

# Capture HTTP code and curl exit separately. Prints: "<http_code> <curl_exit>".
# kubectl exec propagates the remote curl exit code. Pod/kubectl failures are
# surfaced as a non-zero curl_exit with http_code 000 — callers must not treat
# that as a policy PASS without classify_negative_probe.
probe_http() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local container out rc
  container="$(client_container "${ns}" "${pod}")"
  set +e
  out="$(kubectl -n "${ns}" exec "${pod}" -c "${container}" -- \
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "${url}" 2>/dev/null)"
  rc=$?
  set -e
  if [[ -z "${out}" ]]; then
    out="000"
  fi
  # Trim whitespace/newlines from http_code.
  out="$(printf '%s' "${out}" | tr -d '[:space:]')"
  if [[ ! "${out}" =~ ^[0-9]+$ ]]; then
    out="000"
  fi
  echo "${out} ${rc}"
}

http_code() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local result
  result="$(probe_http "${ns}" "${pod}" "${url}")"
  echo "${result%% *}"
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

# Negative mTLS assert: PASS only on explicit rejection (TLS/reset or 403/503).
# DNS failure, timeout, missing pod, or bare non-200 must FAIL (no masking).
assert_mtls_plaintext_rejected() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local label="$4"
  local http_code curl_exit classification

  if ! kubectl -n "${ns}" get pod "${pod}" >/dev/null 2>&1; then
    echo "FAIL: ${label}: pod ${ns}/${pod} does not exist" >&2
    return 1
  fi

  for attempt in $(seq 1 18); do
    read -r http_code curl_exit < <(probe_http "${ns}" "${pod}" "${url}")
    classification="$(classify_negative_probe mtls "${http_code}" "${curl_exit}")"
    echo "${label} attempt ${attempt}: HTTP ${http_code} curl_exit ${curl_exit} -> ${classification}"

    case "${classification}" in
      pass)
        echo "PASS: ${label} explicit mTLS rejection (HTTP ${http_code}, curl_exit ${curl_exit})"
        return 0
        ;;
      fail_allowed)
        echo "FAIL: ${label} unexpectedly allowed (HTTP 200)" >&2
        return 1
        ;;
      fail_infra)
        echo "FAIL: ${label} infra/error signal, not an explicit mTLS rejection (HTTP ${http_code}, curl_exit ${curl_exit})" >&2
        return 1
        ;;
      inconclusive)
        ;;
    esac
    sleep 2
  done
  echo "FAIL: ${label} no explicit mTLS rejection after retries (last HTTP ${http_code}, curl_exit ${curl_exit})" >&2
  return 1
}

# Negative egress assert: PASS only on explicit block (403/502/503 or refuse/reset).
# Timeout/DNS must FAIL — they do not prove REGISTRY_ONLY.
assert_egress_blocked() {
  local ns="$1"
  local pod="$2"
  local url="$3"
  local label="$4"
  local http_code curl_exit classification

  if ! kubectl -n "${ns}" get pod "${pod}" >/dev/null 2>&1; then
    echo "FAIL: ${label}: pod ${ns}/${pod} does not exist" >&2
    return 1
  fi

  for attempt in $(seq 1 18); do
    read -r http_code curl_exit < <(probe_http "${ns}" "${pod}" "${url}")
    classification="$(classify_negative_probe egress "${http_code}" "${curl_exit}")"
    echo "${label} attempt ${attempt}: HTTP ${http_code} curl_exit ${curl_exit} -> ${classification}"

    case "${classification}" in
      pass)
        echo "PASS: ${label} explicit egress block (HTTP ${http_code}, curl_exit ${curl_exit})"
        return 0
        ;;
      fail_allowed)
        echo "FAIL: ${label} unexpectedly reached ${url} (HTTP 200)" >&2
        return 1
        ;;
      fail_infra)
        echo "FAIL: ${label} infra/error signal, not an explicit egress block (HTTP ${http_code}, curl_exit ${curl_exit})" >&2
        return 1
        ;;
      inconclusive)
        ;;
    esac
    sleep 2
  done
  echo "FAIL: ${label} no explicit egress block after retries (last HTTP ${http_code}, curl_exit ${curl_exit})" >&2
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
assert_mtls_plaintext_rejected plaintext plain-client "${BACKEND_URL}/" "plaintext-mtls"

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

echo "=== Test 8a: egress positive control — allowlisted host must succeed ==="
wait_for_code frontend auth-client "${ALLOWED_EGRESS_URL}" 200 "egress-allow-httpbin"

echo "=== Test 8b: egress to non-allowlisted host blocked (REGISTRY_ONLY) ==="
# example.com is not in the ServiceEntry allowlist; REGISTRY_ONLY must block it.
assert_egress_blocked frontend auth-client "${DENIED_EGRESS_URL}" "egress-deny-example"

echo "All policy checks passed."
