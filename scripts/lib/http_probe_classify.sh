#!/usr/bin/env bash
# Pure classification helpers for negative HTTP/TLS probes.
# Sourced by scripts/test_policy.sh and scripts/test_http_probe_classify.sh.
# No cluster access — inputs are simulated or captured curl results.

# classify_negative_probe <kind> <http_code> <curl_exit>
# kind: mtls | egress
#
# Prints one of:
#   pass          — explicit policy rejection (only valid PASS for negative tests)
#   fail_allowed  — request succeeded (HTTP 200); policy did not block
#   fail_infra    — DNS/timeout/missing probe signal; test is not exercising policy
#   inconclusive  — neither an explicit block nor a known infra failure
#
# Never invents numbers: callers must pass the real HTTP code and curl exit code.
classify_negative_probe() {
  local kind="$1"
  local http_code="$2"
  local curl_exit="$3"

  if [[ -z "${kind}" || -z "${http_code}" || -z "${curl_exit}" ]]; then
    echo "fail_infra"
    return 0
  fi

  # DNS failure (6) or timeout (28) — not a policy signal.
  if [[ "${curl_exit}" == "6" || "${curl_exit}" == "28" ]]; then
    echo "fail_infra"
    return 0
  fi

  # Empty/missing HTTP code with no usable curl signal.
  if [[ "${http_code}" == "" ]]; then
    echo "fail_infra"
    return 0
  fi

  # Negative tests must never treat a successful fetch as PASS.
  if [[ "${http_code}" == "200" ]]; then
    echo "fail_allowed"
    return 0
  fi

  case "${kind}" in
    mtls)
      # Explicit Envoy/auth rejection.
      if [[ "${http_code}" == "403" || "${http_code}" == "503" ]]; then
        echo "pass"
        return 0
      fi
      # TLS / connection-reset failures from STRICT mTLS (curl exit codes).
      if [[ "${curl_exit}" == "35" || "${curl_exit}" == "52" || "${curl_exit}" == "56" ]]; then
        echo "pass"
        return 0
      fi
      ;;
    egress)
      # Explicit block from the egress path / Envoy.
      if [[ "${http_code}" == "403" || "${http_code}" == "502" || "${http_code}" == "503" ]]; then
        echo "pass"
        return 0
      fi
      # REGISTRY_ONLY typically refuses or resets the connection.
      if [[ "${curl_exit}" == "7" || "${curl_exit}" == "56" ]]; then
        echo "pass"
        return 0
      fi
      ;;
    *)
      echo "fail_infra"
      return 0
      ;;
  esac

  # Non-200 that is not an explicit rejection (includes bare 000 without a
  # matching curl exit) must not be masked as PASS.
  echo "inconclusive"
  return 0
}
