#!/bin/bash

# Set variables
ALB_Version="2.11.0"
ALB_ING_V="2_11_0"
CLUSTER="$1"
PROFILE="$2"

# AWS_AC_ID="046874047165"
AWS_AC_ID=$(aws eks describe-cluster --name $CLUSTER --query "cluster.arn" --output text --profile $PROFILE | cut -d: -f5)
echo $AWS_AC_ID

# REGION="ap-south-1"
REGION=$(aws eks describe-cluster --name $CLUSTER --query "cluster.arn" --output text --profile $PROFILE | cut -d: -f4)
echo $REGION

# VPC_ID="vpc-0646ad1c3d7c4ebcf"
VPC_ID=$(aws eks describe-cluster --name $CLUSTER --query "cluster.resourcesVpcConfig.vpcId" --output text --profile $PROFILE)
echo $VPC_ID

# Define version of cert-manager
CERT_MANAGER_V="v1.16.2"

echo "Download the IAM policy..."
wget -c https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/docs/install/iam_policy.json -P ../eks_iam_policies/

echo "Optionally download the default ingressclass and ingressclass params..."
wget -c https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v$ALB_Version/v${ALB_ING_V}_ingclass.yaml -P ../4_eks_ingress/

echo "comment v${ALB_ING_V}_ingclass.yaml all lines once..."
sed -i '/^[^#]/ s/^/# /' ../4_eks_ingress/v2_11_0_ingclass.yaml

# echo "uncomment all the lines..."
# sed -i 's/^# //' ../4_eks_ingress/v2_11_0_ingclass.yaml

echo "Creating IAM policy for AWS Load Balancer Controller..."
aws iam create-policy --profile $PROFILE \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://../eks_iam_policies/iam_policy.json

# Create the IAM service account and attach the IAM policy
echo "Creating IAM service account for ALB and attaching IAM policy..."
eksctl create iamserviceaccount --profile $PROFILE \
    --cluster=$CLUSTER \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=arn:aws:iam::$AWS_AC_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region $REGION \
    --approve
    
echo "Adding EKS Helm chart repository..."
helm repo add eks https://aws.github.io/eks-charts && helm repo update eks

echo "Installing AWS Load Balancer Controller via Helm..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$REGION \
    --set vpcId=$VPC_ID
echo "AWS Load Balancer Controller installed successfully!"

# Update the kubeconfig to connect to the EKS cluster
echo "Updating kubeconfig for the EKS cluster..."
truncate -s 0 ~/.kube/config
aws eks update-kubeconfig --region $REGION --name $CLUSTER --profile $PROFILE

# Verify the deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# ---NEXT---

# helm repo add jetstack https://charts.jetstack.io --force-update
# helm upgrade --install \
#   cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --create-namespace \
#   --version $CERT_MANAGER_V \
#   --set crds.enabled=true \
#   --set webhook.securePort=10260

# Step 1: Apply the cert-manager installation YAML
echo "Applying cert-manager installation YAML version ${CERT_MANAGER_V}..."
wget -c https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_V}/cert-manager.crds.yaml -P ../eks_cert_manager/
# kubectl apply -f ../eks_cert_manager/cert-manager.crds.yaml
wget -c https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_V}/cert-manager.yaml -P ../eks_cert_manager/
# kubectl apply --validate=false -f ../eks_cert_manager/cert-manager.yaml
echo "Cert-manager installation applied successfully."

# Step 2: Update cert-manager deployment (Change port from 10250 to 10260 if POD in pending-state)

echo "Updating cert-manager deployment to use port 10260 instead of 10250..."
# kubectl edit deployment -n cert-manager cert-manager
echo "Deployment updated successfully."

# Step 3: Update cert-manager service (Change targetPort from 10250 to 10260)
echo "Updating cert-manager service to use port 10260 instead of 10250..."
# kubectl edit svc -n cert-manager cert-manager
echo "Service updated successfully."

# Final message
echo "Cert-manager installation completed and port conflict resolved (if any)."

# Help reference link
echo "For more information on potential port conflicts, refer to: https://github.com/cert-manager/cert-manager/issues/3237#issuecomment-827523656"