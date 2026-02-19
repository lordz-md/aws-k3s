#!/bin/bash

yum update -y && yum upgrade -y
yum install git-core jq -y 

IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IMDS_HEADER="X-aws-ec2-metadata-token: $IMDS_TOKEN"

aws_region=$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
master_ip=$(aws ec2 describe-instances --filters "Name=tag:InitialNode,Values=1" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text --region "$aws_region")

local_ip=$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/local-ipv4)
provider_id="$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/instance-id)"
instance_id="$(curl -s -H "$IMDS_HEADER" http://169.254.169.254/latest/meta-data/instance-id)"

CUR_HOSTNAME=$(cat /etc/hostname)
NEW_HOSTNAME=$instance_id

hostnamectl set-hostname $NEW_HOSTNAME
hostname $NEW_HOSTNAME

sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.24.9+k3s1 K3S_TOKEN=Ex4mpL3T0k3N K3S_URL=https://"$master_ip":6443 sh -s - agent --node-ip $local_ip --kubelet-arg="provider-id=aws:///$provider_id"

sleep 5
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
sleep 5
source ~/.bashrc
