#!/bin/bash

# Set variables
externalTrafficPolicy=Local
serviceType=NodePort
ingress_Ns=kube-system

echo "refLink: https://kubernetes.github.io/ingress-nginx/deploy/#aws & https://rajeshwrn.github.io/alb-nginx-controller/ ..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# # It will install the controller in the ingress-nginx namespace, creating that namespace if it doesn't already exist.
# helm upgrade --install ingress-nginx ingress-nginx \
#   --repo https://kubernetes.github.io/ingress-nginx \
  # --namespace $ingress_Ns --create-namespace

# OR
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --set-string controller.service.externalTrafficPolicy=$externalTrafficPolicy \
  --set-string controller.service.type=$serviceType \
  --set controller.publishService.enabled=true \
  --set serviceAccount.create=true --set rbac.create=true \
  --set-string controller.config.server-tokens=false \
  --set-string controller.config.use-proxy-protocol=false \
  --set-string controller.config.compute-full-forwarded-for=true \
  --set-string controller.config.use-forwarded-headers=true \
  --set controller.metrics.enabled=true \
  --set controller.autoscaling.maxReplicas=2 \
  --set controller.autoscaling.minReplicas=2 \
  --set controller.autoscaling.enabled=true \
  --namespace $ingress_Ns -f values-ingress-nginx.yaml 

# If you want a full list of values that you can set, while installing with Helm, then run:
# helm show values ingress-nginx --repo https://kubernetes.github.io/ingress-nginx
# curl -o default-values-ingress-nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/heads/main/charts/ingress-nginx/values.yaml

# The following command will wait for the ingress controller pod to be up, running, and ready:
# kubectl wait --namespace $ingress_Ns \
#   --for=condition=ready pod \
#   --selector=app.kubernetes.io/component=controller \
#   --timeout=120s

# kubectl port-forward --namespace=$ingress_Ns service/ingress-nginx-controller 8080:80

# Network Load Balancer (NLB) ¶
curl -o aws-ng-nginx-ingress.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/heads/main/deploy/static/provider/aws/deploy.yaml
# kubectl apply -f aws-ng-nginx-ingress.yaml

# Network Load Balancer (NLB-TLS) ¶
curl -o aws-ng-nginx-tls-ingress.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/heads/main/deploy/static/provider/aws/nlb-with-tls-termination/deploy.yaml
# kubectl apply -f aws-ng-nginx-tls-ingress.yaml

# Edit the file and change the VPC CIDR in use for the Kubernetes cluster:
# proxy-real-ip-cidr: XXX.XXX.XXX/XX

# Change the AWS Certificate Manager (ACM) ID as well:
# arn:aws:acm:us-west-2:XXXXXXXX:certificate/XXXXXX-XXXXXXX-XXXXXXX-XXXXXXXX
