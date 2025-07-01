#!/bin/bash

# This script tests the security policies by sending requests to the application

# Get the ingress IP and port
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# Test 1: Access the frontend (should be allowed)
curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_HOST:$INGRESS_PORT/

# Test 2: Access the backend directly (should be denied)
curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_HOST:$INGRESS_PORT/backend
