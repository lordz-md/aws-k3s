#!/bin/bash
set -euo pipefail

yum update -y && yum upgrade -y
yum install -y git-core jq

IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IMDS_HEADER="X-aws-ec2-metadata-token: $IMDS_TOKEN"

local_ip=$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/local-ipv4)
provider_id="$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/instance-id)"

instance_id=$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/instance-id)

CUR_HOSTNAME=$(cat /etc/hostname)
NEW_HOSTNAME=$instance_id

hostnamectl set-hostname "$NEW_HOSTNAME"
hostname "$NEW_HOSTNAME"
sudo sed -i "s|$CUR_HOSTNAME|$NEW_HOSTNAME|g" /etc/hosts
sudo sed -i "s|$CUR_HOSTNAME|$NEW_HOSTNAME|g" /etc/hostname

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.24.9+k3s1 K3S_TOKEN=Ex4mpL3T0k3N sh -s - --cluster-init --node-ip "$local_ip" --advertise-address "$local_ip" --kubelet-arg="cloud-provider=external" --flannel-backend=none --disable-network-policy --cluster-cidr=192.168.0.0/16 --disable-cloud-controller --disable servicelb --disable traefik --write-kubeconfig-mode 600 --kubelet-arg="provider-id=aws:///$provider_id"

kubectl apply -f https://github.com/aws/aws-node-termination-handler/releases/download/v1.18.2/all-resources.yaml
kubectl apply -f https://raw.githubusercontent.com/lordz-md/aws-k3s/master/rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/lordz-md/aws-k3s/master/aws-cloud-controller-manager-daemonset.yaml
sleep 15
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/custom-resources.yaml

sleep 5
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
sleep 5
source ~/.bashrc

