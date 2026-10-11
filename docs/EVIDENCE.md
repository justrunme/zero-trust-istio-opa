# Evidence

Maps zero-trust mesh claims to CI proof. Status vocabulary: **Tested in CI** /
**Reference implementation** / **Simulated** / **Not yet**.

Pins are from `scripts/versions.env` / `.github/workflows/ci.yml`. No invented latency SLOs.

## Claim table

| Claim | Status | Scenario + environment | Real limits | Proof link | Negative tests |
| --- | --- | --- | --- | --- | --- |
| STRICT mTLS + deny-by-default AuthorizationPolicy paths | Tested in CI | Job **zero-trust-e2e**; kind **v0.33.0**; node `kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0`; Istio **1.31.1**; namespaces frontend/backend/db | Single-node kind lab — not multi-cluster mesh federation | Latest green: [38120845900](https://github.com/justrunme/zero-trust-istio-opa/actions/runs/38120845900) · SHA `ed27a92d8dd69ead0e083c4d690e33731d89b13a` · artifacts `zero-trust-security-report`, `deployment-logs` | Unauthorized principal must not get 200; plaintext from non-mesh ns rejected |
| OPA as Istio external authorizer (`action: CUSTOM`) on backend | Tested in CI | Same e2e; OPA/OPA-Envoy **1.21.1**; Rego from `opa/policy.rego` generated into ConfigMap at deploy | Ext-authz on demo apps only; Rego policy is lab-sized | Same run · OPA decision logs in security report artifact (allow frontend→backend, deny db→backend, deny `/admin`) | Path deny `/admin` → **403**; wrong SA → **403** |
| Gatekeeper required `app` label admission | Tested in CI | Gatekeeper Helm chart **3.23.1**; constraint `must-have-app-label` | Admission only for Deployments in demo namespaces | Same run · artifact shows constraint enforced | Unlabeled Deployment fixture must be denied |
| Egress REGISTRY_ONLY + ServiceEntry allowlist | Tested in CI | Sidecar outbound policy in app namespaces; allowlist includes `httpbin.org` | Only exercise hosts the test script covers | Same run · `scripts/test_policy.sh` | Non-allowlisted host blocked |
| Unit policy tests (OPA coverage threshold, Conftest, actionlint) | Tested in CI | Job **lint-and-unit** (`opa test --coverage --threshold 90`, Conftest) | Unit/conftest ≠ full mesh e2e | Same run · job lint-and-unit | Coverage/threshold or conftest fail CI |
| Multi-cluster / ambient mesh / production IdP integration | Not yet | Out of current demo scope | — | — | — |

## Not proven / out of scope

- Multi-primary Istio across regions
- Enterprise PKI/SPIFFE issuance beyond kind demo identities
- Performance/latency budgets for ext_authz under production RPS

## How to reproduce

```bash
./scripts/deploy_all.sh
./scripts/test_policy.sh
```

CI: `.github/workflows/ci.yml` (`lint-and-unit`, `zero-trust-e2e`).
