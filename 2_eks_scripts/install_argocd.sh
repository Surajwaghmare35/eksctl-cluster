#!/bin/bash

# Set variables
ARGO_NS=argocd
PROFILE="$1"
REGION="ap-south-1"  # AWS region
ECR_URL="046874047165.dkr.ecr.ap-south-1.amazonaws.com"  # ECR URL

echo "Creating the ArgoCD namespace: $ARGO_NS"
kubectl create namespace $ARGO_NS

echo "Downloading the ArgoCD & CRDS installation manifest"
wget -c https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -P ../argoCD/

# echo "Applying the ArgoCD installation manifest to the Kubernetes cluster"
# kubectl apply -n $ARGO_NS -f ../argoCD/install.yaml

# kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable

echo "Adding the Argo Helm repository"
helm repo add argo https://argoproj.github.io/argo-helm

echo "Installing ArgoCD using Helm in the $ARGO_NS namespace"
helm install argo-cd argo/argo-cd -n $ARGO_NS 

# NOTES:
# In order to access the server UI you have the following options:
# echo "NOTE: In order to access the ArgoCD server UI you have the following options:"

# echo "1. Use kubectl port-forward to access UI on localhost:8080"
# echo "   Command: kubectl port-forward service/argo-cd-argocd-server -n $ARGO_NS 8080:443"
# echo "   Then, open your browser on http://localhost:8080 and accept the certificate."

# echo "2. Alternatively, enable ingress in the values file for SSL passthrough or SSL termination."
# echo "   - For SSL passthrough, refer to the ArgoCD documentation: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough"
# echo "   - For SSL termination, modify the values file with server.insecure configuration: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts"

echo "Applying the ArgoCD 'argogrpc' SVC"
kubectl apply -f ../argoCD/argocdgrpc-svc.yaml

echo "After accessing the UI, you can log in with username: admin and the random password generated during installation."
echo "To retrieve the password, run the following command:"
kubectl -n $ARGO_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo

echo "annotatig argocd svc ..."
kubectl annotate svc -n $ARGO_NS argogrpc alb.ingress.kubernetes.io/healthcheck-path="/applications" --overwrite
kubectl annotate svc -n $ARGO_NS argo-cd-argocd-server alb.ingress.kubernetes.io/healthcheck-path="/applications" --overwrite

# Suggest to delete initial secret after first login
echo "NOTE: It is recommended to delete the initial admin secret after logging in as suggested by the ArgoCD Getting Started Guide."
echo "For more details, visit: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli"

# NEXT
echo "Installing or upgrading ArgoCD Image Updater..."
helm upgrade -i argocd-image-updater argo/argocd-image-updater -n $ARGO_NS -f ../eks_values_files/values-argocd-image-updater.yaml

# echo "Retrieving authentication token for AWS ECR..."
# aws ecr get-login-password --region $REGION --profile $PROFILE | docker login --username AWS --password-stdin $ECR_URL

echo "Retrieving and decoding AWS ECR authorization token..."
aws ecr --region $REGION get-authorization-token --output text --query 'authorizationData[].authorizationToken' | base64 -d