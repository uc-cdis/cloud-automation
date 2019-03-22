#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

# Upper case variables are local, lower case are handled by terraform.
# We use double dollar signs ($$) because terraform uses the same sintax for variables.
 
sudo sysctl fs.inotify.max_user_watches=12000

KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool}"

PROXY="http://csoc-cloud-proxy.internal.io:3128"

if ! [ -d /etc/systemd/system/docker.service.d ];
then
    sudo mkdir -p /etc/systemd/system/docker.service.d
fi
cat  > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY" "HTTPS_PROXY=$PROXY" "NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,kibana.planx-pla.net,.amazonaws.com,.amazon.com"
EOF


echo "export HTTP_PROXY=$PROXY" |sudo tee -a /etc/sysconfig/docker
echo "export HTTPS_PROXY=$PROXY" |sudo tee -a /etc/sysconfig/docker
echo "export NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,kibana.planx-pla.net,.amazonaws.com,.amazon.com" |sudo tee -a /etc/sysconfig/docker


if [[ ${nodepool} == jupyter ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi
/etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name}

cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/authorized_keys

# forcing a restart of docker at the very end, it seems like the changes are not picked up for some reason
systemctl daemon-reload
systemctl restart docker
