#!/bin/bash

# Set variables
cluster_name="$1"
profile="$2"

echo "Retrieve the OIDC issuer URL for the cluster..."
oidc_id=$(aws eks describe-cluster --name "$cluster_name" --query "cluster.identity.oidc.issuer" --output text --profile $profile | cut -d '/' -f 5)

# Print OIDC ID
echo "OIDC ID: $oidc_id"

echo "List IAM OpenID Connect providers and filter for the OIDC ID of the cluster..."
provider_arn=$(aws iam list-open-id-connect-providers --profile $profile | grep "$oidc_id" | cut -d "/" -f4)

# Print the provider ARN
echo "Provider ARN: $provider_arn"

echo "Associate IAM OIDC provider with EKS cluster..."
eksctl utils associate-iam-oidc-provider --cluster "$cluster_name" --approve --profile $profile

echo "Reference URL for further reading..."
echo "For more details, refer to: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html"
