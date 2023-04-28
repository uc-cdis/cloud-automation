MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

# Upper case variables are local, lower case are handled by terraform.
# Bracket enclosed variables are handled by terraform. Non encloses variables are local to this script

 
cat >> /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

sysctl fs.inotify.max_user_watches=12000

KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool}"

PROXY="http://csoc-cloud-proxy.internal.io:3128"

if ! [ -d /etc/systemd/system/docker.service.d ];
then
    mkdir -p /etc/systemd/system/docker.service.d
fi
cat  > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY" "HTTPS_PROXY=$PROXY" "NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,.planx-pla.net,.amazonaws.com,.amazon.com"
EOF


echo "export HTTP_PROXY=$PROXY" |tee -a /etc/sysconfig/docker
echo "export HTTPS_PROXY=$PROXY" |tee -a /etc/sysconfig/docker
echo "export NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,kibana.planx-pla.net,.amazonaws.com,.amazon.com" |tee -a /etc/sysconfig/docker


if [[ ${nodepool} != default ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi
/etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} --apiserver-endpoint ${eks_endpoint} --b64-cluster-ca ${eks_ca}



# forcing a restart of docker at the very end, it seems like the changes are not picked up for some reason
systemctl daemon-reload
systemctl restart docker

# Install qualys agent if the activtion and customer id provided
if [[ ! -z "${activation_id}" ]] || [[ ! -z "${customer_id}" ]]; then
    aws s3 cp s3://qualys-agentpackage/QualysCloudAgent.rpm ./qualys-cloud-agent.x86_64.rpm
    sudo rpm -ivh qualys-cloud-agent.x86_64.rpm
    # Clean up rpm package after install
    rm qualys-cloud-agent.x86_64.rpm
    sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=${activation_id} CustomerId=${customer_id}
fi

sudo yum update -y
sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
sudo  dracut -f
# configure grub
sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

--BOUNDARY
Content-Type: text/cloud-config; charset="us-ascii"

power_state:
    delay: now
    mode: reboot
    message: Powering off
    timeout: 2
    condition: true

--BOUNDARY--