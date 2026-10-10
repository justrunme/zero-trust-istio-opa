package istio.authz

import rego.v1

# Deny by default; only explicit allow rules may permit traffic.
default allow := false

# Health checks are always permitted.
allow if {
	count(input.parsed_path) > 1
	input.parsed_path[1] == "healthz"
}

# Frontend may call backend with GET.
allow if {
	input.attributes.request.http.method == "GET"
	input.attributes.source.namespace == "frontend"
	input.attributes.destination.namespace == "backend"
}
