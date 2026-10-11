package istio.authz

import rego.v1

# Deny by default. Decisions are evaluated against the Envoy CheckRequest
# shape produced by Istio's envoyExtAuthzGrpc extension provider.
default allow := false

# Exact health check path only (GET /healthz). Rejects prefixes like
# /healthz/anything and path-traversal style segments.
allow if {
	input.attributes.request.http.method == "GET"
	input.parsed_path == ["healthz"]
}

# Frontend workload identity may GET allowlisted paths on backend.
allow if {
	input.attributes.request.http.method == "GET"
	source_principal_matches("frontend", "frontend")
	path_allowlisted
}

# Parse SPIFFE URI from input.attributes.source.principal.
# Example: spiffe://cluster.local/ns/frontend/sa/frontend
source_principal_matches(namespace, service_account) if {
	principal := object.get(input.attributes.source, "principal", "")
	principal == sprintf("spiffe://cluster.local/ns/%s/sa/%s", [namespace, service_account])
}

# Allow only the root and /api/* tree. Everything else (e.g. /admin) is denied.
path_allowlisted if {
	input.parsed_path == []
}

path_allowlisted if {
	input.parsed_path == [""]
}

path_allowlisted if {
	count(input.parsed_path) >= 1
	input.parsed_path[0] == "api"
}
