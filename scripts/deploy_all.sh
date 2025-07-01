#!/bin/bash

export PATH="$PATH:/Users/justrunme/kubectl/zero-trust-istio-opa/istio-1.26.2/bin"

# This script deploys the entire application stack, including:
# - Minikube
# - Istio
# - The application microservices

# Start Minikube
minikube start

# Install Istio
istioctl install --set profile=demo -y

# Apply the application manifests
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/app/
kubectl apply -f manifests/istio/

# Apply the OPA policies
kubectl apply -f policies/
