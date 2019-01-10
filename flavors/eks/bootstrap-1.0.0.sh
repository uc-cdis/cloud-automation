#!/bin/bash -xe

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform template here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt

MODEL_DIRECTORY_PATH=~/.aws/eks
MODEL_FILE_PATH=$MODEL_DIRECTORY_PATH/eks-2017-11-01.normal.json

mkdir -p $CA_CERTIFICATE_DIRECTORY

mkdir -p $MODEL_DIRECTORY_PATH
curl -o $MODEL_FILE_PATH https://s3-us-west-2.amazonaws.com/amazon-eks/1.10.3/2018-06-05/eks-2017-11-01.normal.json
aws configure add-model --service-model file://$MODEL_FILE_PATH --service-name eks

echo "${eks_ca}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${eks_endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${vpc_name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${eks_region},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${eks_endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
sed -i "/node-ip/a --node-labels=role=${nodepool} \\\\" /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

sudo cat /home/ec2-user/.ssh/authorized_keys > /root/.ssh/authorized_keys
