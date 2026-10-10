package main

import rego.v1

# Conftest policy: Deployments in app manifests must carry an app label.
deny contains msg if {
	input.kind == "Deployment"
	not input.metadata.labels.app
	msg := sprintf("Deployment %q must set metadata.labels.app", [input.metadata.name])
}

deny contains msg if {
	input.kind == "Deployment"
	not input.spec.template.metadata.labels.app
	msg := sprintf("Deployment %q must set spec.template.metadata.labels.app", [input.metadata.name])
}
