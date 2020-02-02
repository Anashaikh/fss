#!/usr/bin/env bash
set -e -o pipefail

echo "===================================================="
echo "Getting data from Terraform output..."
echo "===================================================="
TF_OUTPUT=$(cd terraform && terraform output -json)
CLUSTER_NAME="$(echo ${TF_OUTPUT} | jq -r .k8s_cluster_name.value)"
STATE="s3://$(echo ${TF_OUTPUT} | jq -r .kops_s3_bucket.value)"

echo "Cluster Name...: ${CLUSTER_NAME}"

echo "===================================================="
echo "Generating Kubernetes Add-ons yaml files"
echo "===================================================="
cd kubernetes

echo "===================================================="
echo "External DNS Controller"
echo "===================================================="
helm install stable/external-dns \
--atomic \
--replace \
--name external-dns \
--namespace external-dns \
--values helm-values/external-dns.yaml

echo "===================================================="
echo "Installing Mysql Server"
echo "===================================================="
helm install --name my-release stable/mysql -f kubernetes/helm-values/mysql.yaml

echo "===================================================="
echo "Creaging Flight Schedule Service pod - parsing airlines.dat into the mysql database "
echo "===================================================="
kubectl create -f kubernetes/helm-values/parse-data-configmap.yaml
kubectl create -f kubernetes/helm-values/quantum-parse-data.yaml

MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default my-release-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
kubectl create secret generic db-pass --from-literal=password=$MYSQL_ROOT_PASSWORD

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
echo "===================================================="
echo "CI/CD Jenkins Server"
echo "===================================================="
helm install stable/jenkins \
--atomic \
--name jenkins \
--namespace jenkins \
--values helm-values/jenkins.yaml \
--set "master.adminUser=" \
--set "master.adminPassword=" \
--set "master.ingress.hostName=jenkins.${CLUSTER_NAME}" \

kubectl create clusterrolebinding permissive-binding \
--clusterrole=cluster-admin \
--user=admin \
--user=kubelet \
--group=system:serviceaccounts:jenkins

echo "===================================================="
echo "Grafana Monitoring"
echo "===================================================="
helm install stable/grafana
echo "===================================================="
echo "Prometheus"
echo "===================================================="
helm install stable/prometheus
