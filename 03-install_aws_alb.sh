#!/bin/bash

# Set variables
ALB_Version="2.10.0"
CLUSTER="$1"
PROFILE="$2"
AWS_AC_ID="046874047165"
REGION="ap-south-1"
VPC_ID="vpc-0c9ba5790412a152e"

echo "Download the IAM policy..."
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v$ALB_Version/docs/install/iam_policy.json

echo "Creating IAM policy for AWS Load Balancer Controller..."
aws iam create-policy --profile $PROFILE \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

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
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

echo "Installing AWS Load Balancer Controller via Helm..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$REGION \
    --set vpcId=$VPC_ID
echo "AWS Load Balancer Controller installed successfully!"

# Update the kubeconfig to connect to the EKS cluster
echo "Updating kubeconfig for the EKS cluster..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER --profile $PROFILE

# Verify the deployment
kubectl get deployment -n kube-system aws-load-balancer-controller
