# refLink: https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
# refLink: https://repost.aws/knowledge-center/eks-cluster-kubernetes-dashboard


# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

# NOTES:
# To access Dashboard run:
#   kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

kubectlapply -f dashboard-adminuser.yaml 
