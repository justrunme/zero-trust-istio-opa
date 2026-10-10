package istio.authz_test

import rego.v1

import data.istio.authz

test_allow_frontend_to_backend if {
	authz.allow with input as {
		"attributes": {
			"request": {"http": {"method": "GET"}},
			"source": {"namespace": "frontend"},
			"destination": {"namespace": "backend"},
		},
	}
}

test_deny_unauthorized_namespace if {
	not authz.allow with input as {
		"attributes": {
			"request": {"http": {"method": "GET"}},
			"source": {"namespace": "db"},
			"destination": {"namespace": "backend"},
		},
	}
}

test_deny_wrong_method if {
	not authz.allow with input as {
		"attributes": {
			"request": {"http": {"method": "POST"}},
			"source": {"namespace": "frontend"},
			"destination": {"namespace": "backend"},
		},
	}
}

test_allow_healthz if {
	authz.allow with input as {
		"parsed_path": ["", "healthz"],
		"attributes": {
			"request": {"http": {"method": "GET"}},
			"source": {"namespace": "unknown"},
			"destination": {"namespace": "backend"},
		},
	}
}
