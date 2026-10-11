This is a sample security summary. CI uploads a live report artifact instead of
rewriting this file on every run.

### Policy Enforcement Summary

* **Deny-by-Default:** Namespace `allow-nothing` AuthorizationPolicies plus STRICT mTLS.
* **OPA ext_authz:** Backend uses `action: CUSTOM` with provider `opa-ext-authz` (Envoy CheckRequest Rego).
* **Allowed Traffic:** Frontend SA → backend `/` returns HTTP 200; backend SA → db returns HTTP 200.
* **Blocked Traffic:** DB SA → backend HTTP 403; frontend SA → `/admin` HTTP 403 (OPA); frontend → db HTTP 403.
* **mTLS:** Plaintext clients outside the mesh cannot reach backend with HTTP 200.
* **Egress:** `Sidecar` `REGISTRY_ONLY` blocks non-allowlisted external hosts (e.g. example.com).
* **Admission:** Gatekeeper requires Deployments in app namespaces to set an `app` label.
