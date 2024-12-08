#!/bin/bash

echo "RefLink: https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/aws/ ..."
echo "RefLink: https://repost.aws/knowledge-center/eks-set-up-externaldns"

echo "Creating IAM policy for ExternalDNS..."
cat > ../eks_iam_policies/external-dns-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
EOF

echo "Creating IAM policy on AWS..."
aws iam create-policy --policy-name "AllowExternalDNSUpdates" --policy-document file://../eks_iam_policies/external-dns-policy.json --profile $2 | more

# Set Variables
EKS_CLUSTER_NAME=$1
EXTERNALDNS_NS=kube-system
PROFILE=$2
# AWS_AC_ID="046874047165"
AWS_AC_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.arn" --output text --profile $PROFILE | cut -d: -f5)
POLICY_ARN=arn:aws:iam::$AWS_AC_ID:policy/AllowExternalDNSUpdates

echo "Associating IAM OIDC provider with EKS cluster $EKS_CLUSTER_NAME..."
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve --profile $PROFILE

echo "Creating IAM service account for ExternalDNS in namespace $EXTERNALDNS_NS..."
eksctl create iamserviceaccount --profile $PROFILE\
  --cluster $EKS_CLUSTER_NAME \
  --name "external-dns" \
  --namespace $EXTERNALDNS_NS \
  --attach-policy-arn $POLICY_ARN \
  --approve

  # --namespace ${EXTERNALDNS_NS:-"default"} 
  # --namespace ${EXTERNALDNS_NS:-"kube-system"} 

# echo "Installing ExternalDNS using RBAC Manifest..."
# kubectl apply -f ../eks_external_dns/external-dns-rbac.yaml

echo "Adding ExternalDNS Helm chart repository..."
# helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ && helm repo update
echo "Installing or upgrading ExternalDNS using Helm..."
helm upgrade -i external-dns external-dns/external-dns --values ../eks_values_files/values-external-dns.yaml