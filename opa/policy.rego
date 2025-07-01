package istio.authz

default allow = false

allow {
    input.parsed_path[1] == "healthz"
}

allow {
    input.attributes.request.http.method == "GET"
    input.attributes.source.namespace == "frontend"
    input.attributes.destination.namespace == "backend"
}
