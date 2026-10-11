package main

import rego.v1

# Combined-input checks for manifests/istio (conftest --combine).
# Ensures each app namespace has STRICT mTLS and an explicit deny-by-default policy.

app_namespaces := {"frontend", "backend", "db"}

deny contains msg if {
	is_combine_input
	some ns in app_namespaces
	not has_strict_peer_auth(ns)
	msg := sprintf("namespace %q must have PeerAuthentication with STRICT mTLS", [ns])
}

deny contains msg if {
	is_combine_input
	some ns in app_namespaces
	not has_allow_nothing(ns)
	msg := sprintf("namespace %q must have AuthorizationPolicy allow-nothing (deny-by-default)", [ns])
}

is_combine_input if {
	count(input) > 0
	input[0].contents.kind
}

has_strict_peer_auth(ns) if {
	some doc in input
	doc.contents.kind == "PeerAuthentication"
	doc.contents.metadata.namespace == ns
	doc.contents.spec.mtls.mode == "STRICT"
}

has_allow_nothing(ns) if {
	some doc in input
	doc.contents.kind == "AuthorizationPolicy"
	doc.contents.metadata.namespace == ns
	doc.contents.metadata.name == "allow-nothing"
	not doc.contents.spec.action
	object.get(doc.contents.spec, "rules", null) == null
}
