#!/bin/bash
set -euo pipefail

# Set context to web-admin user
kubectl config use-context web-admin-context

kubectl create deployment nginx --image=nginx --replicas=2
kubectl expose deployment nginx --port=80 --type=ClusterIP