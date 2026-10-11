package istio.authz_test

import rego.v1

import data.istio.authz

# Realistic Envoy CheckRequest fixtures (Istio ext_authz gRPC input).

frontend_get_root := {
	"parsed_path": [],
	"attributes": {
		"source": {
			"principal": "spiffe://cluster.local/ns/frontend/sa/frontend",
			"address": {"socketAddress": {"address": "10.244.0.10", "portValue": 45678}},
		},
		"destination": {
			"principal": "spiffe://cluster.local/ns/backend/sa/backend",
			"address": {"socketAddress": {"address": "10.244.0.20", "portValue": 80}},
		},
		"request": {"http": {
			"method": "GET",
			"path": "/",
			"host": "backend.backend.svc.cluster.local",
			"headers": {
				":method": "GET",
				":path": "/",
				":authority": "backend.backend.svc.cluster.local",
			},
		}},
	},
}

frontend_get_api := {
	"parsed_path": ["api", "orders"],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/frontend/sa/frontend"},
		"request": {"http": {
			"method": "GET",
			"path": "/api/orders",
			"headers": {":method": "GET", ":path": "/api/orders"},
		}},
	},
}

frontend_get_admin := {
	"parsed_path": ["admin"],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/frontend/sa/frontend"},
		"request": {"http": {
			"method": "GET",
			"path": "/admin",
			"headers": {":method": "GET", ":path": "/admin"},
		}},
	},
}

db_get_root := {
	"parsed_path": [],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/db/sa/db"},
		"request": {"http": {
			"method": "GET",
			"path": "/",
			"headers": {":method": "GET", ":path": "/"},
		}},
	},
}

frontend_post_root := {
	"parsed_path": [],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/frontend/sa/frontend"},
		"request": {"http": {
			"method": "POST",
			"path": "/",
			"headers": {":method": "POST", ":path": "/"},
		}},
	},
}

healthz_ok := {
	"parsed_path": ["healthz"],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/backend/sa/backend"},
		"request": {"http": {
			"method": "GET",
			"path": "/healthz",
			"headers": {":method": "GET", ":path": "/healthz"},
		}},
	},
}

healthz_prefix_bypass := {
	"parsed_path": ["healthz", "anything"],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/db/sa/db"},
		"request": {"http": {
			"method": "GET",
			"path": "/healthz/anything",
			"headers": {":method": "GET", ":path": "/healthz/anything"},
		}},
	},
}

healthz_traversal := {
	"parsed_path": ["healthz", "..", "admin"],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/db/sa/db"},
		"request": {"http": {
			"method": "GET",
			"path": "/healthz/../admin",
			"headers": {":method": "GET", ":path": "/healthz/../admin"},
		}},
	},
}

missing_principal := {
	"parsed_path": [],
	"attributes": {
		"source": {},
		"request": {"http": {"method": "GET", "path": "/"}},
	},
}

frontend_get_root_empty_segment := {
	"parsed_path": [""],
	"attributes": {
		"source": {"principal": "spiffe://cluster.local/ns/frontend/sa/frontend"},
		"request": {"http": {
			"method": "GET",
			"path": "/",
			"headers": {":method": "GET", ":path": "/"},
		}},
	},
}

test_allow_frontend_get_root if {
	authz.allow with input as frontend_get_root
}

test_allow_frontend_get_root_empty_segment if {
	authz.allow with input as frontend_get_root_empty_segment
}

test_allow_frontend_get_api if {
	authz.allow with input as frontend_get_api
}

test_deny_frontend_get_admin if {
	not authz.allow with input as frontend_get_admin
}

test_deny_unauthorized_principal if {
	not authz.allow with input as db_get_root
}

test_deny_wrong_method if {
	not authz.allow with input as frontend_post_root
}

test_allow_exact_healthz if {
	authz.allow with input as healthz_ok
}

test_deny_healthz_prefix if {
	not authz.allow with input as healthz_prefix_bypass
}

test_deny_healthz_traversal if {
	not authz.allow with input as healthz_traversal
}

test_deny_missing_principal if {
	not authz.allow with input as missing_principal
}

test_deny_empty_input if {
	not authz.allow with input as {}
}

test_source_principal_helper_positive if {
	authz.source_principal_matches("frontend", "frontend") with input as frontend_get_root
}

test_source_principal_helper_negative if {
	not authz.source_principal_matches("frontend", "frontend") with input as db_get_root
}
