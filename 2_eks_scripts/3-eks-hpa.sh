#!/bin/bash

echo "Starting Metrics Server installation..."
wget -O ../eks_metrics_server/metrics-server.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# echo "Applying metrics-server.yaml..."
# kubectl apply -f ../eks_metrics_server/metrics-server.yaml && echo "Metrics Server installed with kubectl."

echo "Adding Helm repository..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ && helm repo update

echo "Installing or upgrading Metrics Server with Helm..."
helm upgrade --install metrics-server -n kube-system metrics-server/metrics-server --set "containerPort=10251"

echo "Metrics Server installation complete."
echo "For more info= https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html"
echo "For more info= https://www.kubecost.com/kubernetes-autoscaling/kubernetes-hpa/"
echo "For error info= https://github.com/kubernetes-sigs/metrics-server/issues/694#issuecomment-815193036"