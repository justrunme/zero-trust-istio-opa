# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Added
- Grouped Dependabot config (`.github/dependabot.yml`).
- Conftest policy for Deployment `app` labels.
- `scripts/versions.env` as the single pinned-version source for local scripts.

### Removed
- README claims about Minikube-only flow and CI-inserted Trivy/Kubescape/Prowler sections that the workflow did not produce.
