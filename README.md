# Zero-Trust Visualization with Istio + Open Policy Agent (OPA)

## Project Goal

This project demonstrates how to implement a "zero-trust" security model in a Kubernetes environment using Istio as a service mesh and Open Policy Agent (OPA) for policy enforcement. The project includes deploying microservices, observing their interactions, and applying security policies based on the "deny-by-default" principle.

## Key Features

*   **Microservices Deployment:** A simple application with `frontend`, `backend`, and `db` services.
*   **Istio Integration:** Automatic sidecar injection for all services in the mesh.
*   **OPA Policy Enforcement:** Using OPA Gatekeeper to enforce security policies.
*   **Deny-by-Default:** A baseline policy that denies all traffic unless explicitly allowed.
*   **Traffic Visualization:** Using Kiali and Prometheus/Grafana to visualize service-to-service communication and policy enforcement.
*   **CI/CD Pipeline:** A GitHub Actions workflow to automate testing of security policies.

## Technologies

*   **Kubernetes:** Minikube for local development.
*   **Istio:** Service mesh for traffic management, security, and observability.
*   **Open Policy Agent (OPA):** Gatekeeper for policy enforcement.
*   **Kiali:** Service mesh observability and visualization.
*   **Jaeger:** Distributed tracing.
*   **Prometheus & Grafana:** Metrics collection and visualization.
*   **GitHub Actions:** CI/CD for automated policy testing.
*   **curl/hey/k6:** For load testing and policy verification.

## Project Structure

```
zero-trust-istio-opa/
├── README.md                          # Project description, goals, and policy examples
├── .github/
│   └── workflows/
│       └── ci.yml                     # GitHub Actions: policy checks and reports
├── manifests/
│   ├── namespace.yaml                 # Service namespace separation
│   ├── app/
│   │   ├── frontend.yaml              # Frontend service
│   │   ├── backend.yaml               # Backend service
│   │   └── db.yaml                    # Database (can be a mock)
│   └── istio/
│       ├── gateway.yaml               # Istio Gateway
│       ├── virtualservice.yaml       # VirtualService (routing)
│       ├── destinationrule.yaml      # DestinationRule (for Istio)
│       └── istio-injection-label.yaml # Enable sidecar injection
├── policies/
│   ├── allow-frontend-to-backend.yaml  # Example allow policy
│   ├── deny-all.yaml                   # Deny all by default
│   └── templates/
│       └── k8srequiredlabels.yaml      # OPA Gatekeeper template
├── opa/
│   ├── policy.rego                   # Rego policy (if not using Gatekeeper)
│   └── config.yaml                   # OPA External Authz configuration
├── scripts/
│   ├── test_policy.sh                # curl/hey/k6 script for testing
│   └── deploy_all.sh                 # Quick deployment for Minikube + Istio + App
├── dashboards/
│   ├── grafana.json                  # (optional) Grafana dashboard export
│   └── kiali-config.yaml             # Kiali configuration (if needed)
└── SECURITY-REPORT.md                # Summary: which policies were triggered, what was blocked
```
