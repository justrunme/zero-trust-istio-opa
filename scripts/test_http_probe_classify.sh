#!/usr/bin/env bash
# Unit tests for classify_negative_probe (no cluster required).
# Intended for CI job lint-and-unit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/http_probe_classify.sh
source "${ROOT}/scripts/lib/http_probe_classify.sh"

FAILS=0

assert_class() {
  local kind="$1"
  local http_code="$2"
  local curl_exit="$3"
  local expected="$4"
  local label="$5"
  local got
  got="$(classify_negative_probe "${kind}" "${http_code}" "${curl_exit}")"
  if [[ "${got}" == "${expected}" ]]; then
    echo "PASS: ${label} (got ${got})"
  else
    echo "FAIL: ${label} expected ${expected}, got ${got} [kind=${kind} http=${http_code} curl_exit=${curl_exit}]" >&2
    FAILS=$((FAILS + 1))
  fi
}

echo "=== classify_negative_probe: mTLS plaintext rejection ==="
# Explicit PASS signals
assert_class mtls 403 0 pass "mtls HTTP 403 is explicit rejection"
assert_class mtls 503 0 pass "mtls HTTP 503 is explicit rejection"
assert_class mtls 000 35 pass "mtls curl 35 (TLS failure) is explicit rejection"
assert_class mtls 000 52 pass "mtls curl 52 (empty reply) is explicit rejection"
assert_class mtls 000 56 pass "mtls curl 56 (recv/reset) is explicit rejection"

# NEGATIVE: must NOT pass on infra / success / ambiguous 000
assert_class mtls 200 0 fail_allowed "NEGATIVE: mtls HTTP 200 must fail (policy broken)"
assert_class mtls 000 28 fail_infra "NEGATIVE: mtls timeout (curl 28) must fail"
assert_class mtls 000 6 fail_infra "NEGATIVE: mtls DNS failure (curl 6) must fail"
assert_class mtls 000 0 inconclusive "NEGATIVE: mtls bare 000 without TLS/reset exit must not pass"
assert_class mtls 000 7 inconclusive "NEGATIVE: mtls connection refused alone is not listed PASS for mTLS"
assert_class mtls 502 0 inconclusive "NEGATIVE: mtls HTTP 502 is not an accepted mTLS reject signal"

echo "=== classify_negative_probe: egress REGISTRY_ONLY block ==="
assert_class egress 403 0 pass "egress HTTP 403 is explicit block"
assert_class egress 502 0 pass "egress HTTP 502 is explicit block"
assert_class egress 503 0 pass "egress HTTP 503 is explicit block"
assert_class egress 000 7 pass "egress curl 7 (connection refused) is explicit block"
assert_class egress 000 56 pass "egress curl 56 (reset) is explicit block"

# NEGATIVE: must NOT pass on success / infra noise
assert_class egress 200 0 fail_allowed "NEGATIVE: egress HTTP 200 must fail (allowlist bypass)"
assert_class egress 000 28 fail_infra "NEGATIVE: egress timeout (curl 28) must fail"
assert_class egress 000 6 fail_infra "NEGATIVE: egress DNS failure (curl 6) must fail"
assert_class egress 000 0 inconclusive "NEGATIVE: egress bare 000 without refuse/reset must not pass"
# NEGATIVE: HTTPS-to-blackhole often yields curl 35; that must not count as PASS
# (egress deny probes use HTTP so Envoy can return 502 instead).
assert_class egress 000 35 inconclusive "NEGATIVE: egress TLS error (curl 35) alone is not an explicit block"
assert_class egress "" 56 fail_infra "NEGATIVE: empty http_code is infra failure"

echo "=== classify_negative_probe: bad inputs ==="
assert_class mtls 000 "" fail_infra "NEGATIVE: missing curl_exit must fail"
assert_class bogus 403 0 fail_infra "NEGATIVE: unknown kind must fail"

if [[ "${FAILS}" -ne 0 ]]; then
  echo "FAIL: ${FAILS} classifier assertion(s) failed" >&2
  exit 1
fi
echo "All classifier unit tests passed."
