#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
 
sudo sysctl fs.inotify.max_user_watches=120000

KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool}"

if [[ ${nodepool} == jupyter ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi

cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

sudo cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/authorized_keys

aws s3 sync s3://gen3-kernels/4.19.30 ./
rpm -iUv ./4.19.30/kernel*.rpm

chmod +x /etc/rc.d/rc.local

cat >> /etc/rc.d/rc.local <<EOF
if [ -f /var/bootstrapted ];
then
    /etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name}
    touch /var/bootstrapted
fi
EOF

shutdown -rf now
