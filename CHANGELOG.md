# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Istio `extensionProviders` (`opa-ext-authz` gRPC) via `manifests/istio-operator.yaml`.
- OPA-Envoy deployment wired into the mesh with `AuthorizationPolicy action: CUSTOM` on backend.
- Namespace `allow-nothing` AuthorizationPolicies, backend→db allow policy, dedicated ServiceAccounts.
- Egress control: `Sidecar` `REGISTRY_ONLY` + `ServiceEntry` allowlist.
- Kind e2e negative tests: plaintext STRICT rejection, OPA `/admin` 403, Gatekeeper deny, egress block.
- Conftest mesh combine policy for STRICT + allow-nothing coverage.
- OPA unit-test coverage gate (`--threshold 90`) with Envoy `CheckRequest` fixtures.

### Changed
- Rego rewritten for SPIFFE `source.principal` and exact `/healthz` path matching; deny-by-default.
- OPA ConfigMap generated from `opa/policy.rego` at deploy time to prevent Rego/ConfigMap drift.
- README claims updated to match the wired OPA external-authorizer path.

## [1.0.0] - 2026-10-10

### Added
- Grouped Dependabot config (`.github/dependabot.yml`).
- Conftest policy for Deployment `app` labels.
- `scripts/versions.env` as the single pinned-version source for local scripts.
- Security policy, MIT license, and initial changelog.

### Changed
- CI: download OPA/kind binaries to `$RUNNER_TEMP` (writing `./opa` failed because `opa/` is a directory).
- Upgraded Istio to **1.31.1** (supported release) and removed the vendored `istio-1.26.2` tree; `istioctl` is downloaded by scripts/CI.
- Pinned OPA Gatekeeper Helm chart to **3.23.1** and OPA/OPA-Envoy image to **1.21.1**.
- Switched local/CI cluster bootstrap from Minikube to **kind** with node image `kindest/node:v1.35.8` (digest-pinned).
- Moved Istio `AuthorizationPolicy` / `PeerAuthentication` resources under `manifests/istio/`; Gatekeeper templates/constraints stay under `policies/`.
- Reworked GitHub Actions: current action majors, no failure masking (`|| true` / `|| echo`), no auto-commit to `main`.
- CI now fails unless an unauthorized in-mesh request returns **403** and an authorized frontend→backend request returns **200**.
- Updated OPA Rego to OPA 1.x syntax (`import rego.v1`) and added `opa test` coverage.
- Relocated optional OPA-Envoy Kubernetes manifests to `manifests/opa/`.

### Removed
- README claims about Minikube-only flow and CI-inserted Trivy/Kubescape/Prowler sections that the workflow did not produce.
