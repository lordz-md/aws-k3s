#!/bin/bash

yum update -y && yum upgrade -y
yum install jq -y 

aws_region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
master_ip=$(aws ec2 describe-instances --filters "Name=tag:InitialNode,Values=1" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text --region "$aws_region")

local_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
provider_id="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

CUR_HOSTNAME=$(cat /etc/hostname)
NEW_HOSTNAME=$instance_id

hostnamectl set-hostname $NEW_HOSTNAME
hostname $NEW_HOSTNAME

sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.25.5+k3s1 K3S_TOKEN=PuT1nHu1l0R4SAParasha K3S_URL=https://$master_ip:6443 sh -s - agent --node-ip $local_ip --disable-network-policy --cluster-cidr=192.168.0.0/16 --disable-cloud-controller --disable servicelb --disable traefik --kubelet-arg="provider-id=aws:///$provider_id"
