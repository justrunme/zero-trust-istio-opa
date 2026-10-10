This is a sample security summary. CI uploads a live report artifact instead of
rewriting this file on every run.

### Policy Enforcement Summary

* **Deny-by-Default:** Workloads with ALLOW AuthorizationPolicies reject unmatched traffic (HTTP 403).
* **Allowed Traffic:** Frontend (default SA) to Backend GET is permitted (HTTP 200).
* **Blocked Traffic:** Clients in other namespaces (for example `db`) to Backend are denied (HTTP 403).
* **Admission:** Gatekeeper requires Deployments in app namespaces to set an `app` label.
