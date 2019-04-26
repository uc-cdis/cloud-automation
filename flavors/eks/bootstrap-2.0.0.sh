#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
 
sudo cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/authorized_keys

sudo sysctl fs.inotify.max_user_watches=12000

KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool}"

if [[ ${nodepool} == jupyter ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi
/etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name}

cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO
