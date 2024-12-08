#!/bin/bash
echo -e "Master Ref Link: https://aws.amazon.com/blogs/containers/monitoring-amazon-eks-on-aws-fargate-using-prometheus-and-grafana/"
echo
# Set variables
EBS_CSI_NS=kube-system
CLUSTER="$1"
PROFILE="$2"
# AWS_AC_ID="046874047165"
AWS_AC_ID=$(aws eks describe-cluster --name $CLUSTER --query "cluster.arn" --output text --profile $PROFILE | cut -d: -f5)

# Set up Prometheus Namespace
PROM_NS=prometheus
echo "Creating Prometheus namespace..." && kubectl create namespace $PROM_NS

# # Apply Prometheus SC
EBS_AZ=$(kubectl get nodes -o=jsonpath="{.items[0].metadata.labels['topology\.kubernetes\.io\/zone']}")
echo $EBS_AZ
# echo "Update $EBS_AZ in prometheus-sc.yaml and Apply..." && kubectl apply -f ../eks_prom_grafana/prometheus-sc.yaml 


echo "Starting the setup for EBS CSI Driver, Prometheus & Grafana on EKS Cluster: $CLUSTER"

echo "Creating IAM service account for EBS CSI Driver..."
eksctl create iamserviceaccount --profile $PROFILE \
        --name ebs-csi-controller-sa \
        --namespace $EBS_CSI_NS \
        --cluster $CLUSTER \
        --role-name AmazonEKS_EBS_CSI_DriverRole \
        --role-only \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve

echo "IAM service account created successfully."
echo "For more info= https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html"

# echo "For more info= https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#helm"
# curl -o aws-ebs-csi-driver-values.yaml https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/charts/aws-ebs-csi-driver/values.yaml

# helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver && helm repo update

# helm upgrade --install aws-ebs-csi-driver \
#     --namespace $EBS_CSI_NS \
#     aws-ebs-csi-driver/aws-ebs-csi-driver

# kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

echo "Installing AWS EBS CSI Driver addon..."
eksctl create addon --name aws-ebs-csi-driver \
    --cluster $CLUSTER \
    --service-account-role-arn arn:aws:iam::$AWS_AC_ID:role/AmazonEKS_EBS_CSI_DriverRole \
    --force --profile $PROFILE

echo "AWS EBS CSI Driver addon installed."
echo "For more info= https://navyadevops.hashnode.dev/setting-up-prometheus-and-grafana-on-amazon-eks-for-kubernetes-monitoring"
echo "For more info= https://www.eksworkshop.com/docs/fundamentals/storage/ebs/ebs-csi-driver"

# echo "For more info= http://kubernetes.github.io/kube-state-metrics/"
# helm search repo kube-state-metrics
# helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics

wget -c https://github.com/aws-samples/containers-blog-maelstrom/raw/main/fargate-monitoring/prometheus_values.yml -P ../eks_values_files/

echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update

# helm install prometheu prometheus-community/kube-prometheus-stack -n $PROM_NS 

echo "Installing/upgrading Prometheus..."
helm upgrade -i prometheus prometheus-community/prometheus \
    --namespace $PROM_NS \
    --set alertmanager.persistence.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"
    # --set alertmanager.persistence.storageClass="prometheus" \
    # --set server.persistentVolume.storageClass="prometheus"

# kubectl -n prometheus port-forward deploy/prometheus-server 9090

# Below patch will prevent the pods from being scheduled on Fargate nodes in an AWS EKS cluster,
# ensuring that they only run on EC2-based nodes that do not have the
# eks.amazonaws.com/compute-type=fargate label.

# affinity:
#   nodeAffinity:
#     requiredDuringSchedulingIgnoredDuringExecution:
#       nodeSelectorTerms:
#       - matchExpressions:
#         - key: eks.amazonaws.com/compute-type
#           operator: NotIn
#           values:
#           - fargate

# Now edit "kubectl edit ds -n prometheus prometheus-prometheus-node-exporter"
# And add under template spec

echo "Patching the prometheus-prometheus-node-exporter DaemonSet ..."
kubectl patch ds -n prometheus prometheus-prometheus-node-exporter --type='json' -p "$(cat ../eks_iam_policies/patch-prom-affinity.json)" 
echo "DaemonSet patched successfully."
echo "For more info= https://github.com/prometheus-community/helm-charts/issues/2876#issuecomment-1368944783"

echo "Prometheus installed/upgraded successfully."
echo "For more info= https://docs.aws.amazon.com/eks/latest/userguide/deploy-prometheus.html"
echo "For more info= https://blog.kubecost.com/blog/kubernetes-node-affinity/"

echo "Checking the status of Prometheus pods..." && kubectl get pods -n prometheus

# NOTES:
# The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
# prometheus-server.prometheus.svc.cluster.local

# Get the Prometheus server URL by running these commands in the same shell:
#   export POD_NAME=$(kubectl get pods -n prometheus -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
#   kubectl -n prometheus port-forward $POD_NAME 9090

# The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
# prometheus-alertmanager.prometheus.svc.cluster.local

# Get the Alertmanager URL by running these commands in the same shell:
#   export POD_NAME=$(kubectl get pods -n prometheus -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
#   kubectl -n prometheus port-forward $POD_NAME 9093

# The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
# prometheus-prometheus-pushgateway.prometheus.svc.cluster.local

# Get the PushGateway URL by running these commands in the same shell:
#   export POD_NAME=$(kubectl get pods -n prometheus -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
#   kubectl -n prometheus port-forward $POD_NAME 9091

# # kubectl get pods -n prometheus
# export POD_NAME=$(kubectl get pods -n prometheus -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")

# # kubectl -n prometheus port-forward deploy/prometheus-server 9090

echo "Add Grafana Helm repo and update..."
helm repo add grafana https://grafana.github.io/helm-charts && helm repo update

echo "Download AWS Grafana values file..."
wget -c https://raw.githubusercontent.com/aws-samples/containers-blog-maelstrom/main/fargate-monitoring/grafana-values.yaml -P ../eks_values_files/

echo "Installing Grafana using Helm..."
helm upgrade -i grafana grafana/grafana --namespace $PROM_NS \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true
    # --set adminPassword='EKS!sAWSome' \
    # --set ingress.persistence.storageClassName="prometheus"
    # -f ../eks_values_files/grafana-values.yaml

echo "Retrieve credentials..."
ADMIN_USER=$(kubectl get secret -n $PROM_NS grafana -o jsonpath="{.data.admin-user}" | base64 --decode)
ADMIN_PASSWORD=$(kubectl get secret -n $PROM_NS grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "Display credentials..."
echo "Admin User: $ADMIN_USER , Admin Password: $ADMIN_PASSWORD"

# NOTES:
# 1. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:
#    grafana.prometheus.svc.cluster.local

#    Get the Grafana URL to visit by running these commands in the same shell:
#      export POD_NAME=$(kubectl get pods --namespace prometheus -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
#      kubectl --namespace prometheus port-forward $POD_NAME 3000

echo "Install dashboard 7249 : This dashboard gives a cluster level overview of the workloads deployed based on Prometheus metrics."
echo "Install Dashboard 12421 : to track fagate CPU and memory usage against requests."
echo "Install Dashboard 22523 : to see cluster global view."

echo "annotatig prometheus grafana svc ..."
kubectl annotate svc -n $PROM_NS prometheus-server alb.ingress.kubernetes.io/healthcheck-path="/query" --overwrite
kubectl annotate svc -n $PROM_NS grafana alb.ingress.kubernetes.io/healthcheck-path="/login" --overwrite

echo "Grafana installation completed."
