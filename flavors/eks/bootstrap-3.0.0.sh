#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
#
# Uper case vars are local, lowercase are for terrform to handle and replace

if [[ "${kernel}" != "N/A" ]];
then
  S3_LOCATION="s3://gen3-kernels/${kernel}"
else
  S3_LOCATION="s3://gen3-kernels/4.19.30"
fi

KERNEL_FILES='/tmp/gen3-kernel'

# Increasing this for issues related to too many files opened 
sudo sysctl fs.inotify.max_user_watches=120000


# Let us access the workers for troubleshooting purposes
cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

sudo cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/authorized_keys



mkdir $KERNEL_FILES

# Using `aws s3 sync` throws all kind of issues in the logs, using cp instead. 

aws s3 cp --recursive $S3_LOCATION $KERNEL_FILES

rpm -iUv $KERNEL_FILES/kernel*.rpm



# When the host is back up after reboot, it should trigger the eks/bootstrap script for it to join th cluster.
chmod +x /etc/rc.d/rc.local

## EKS connection
KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool}"

if [[ ${nodepool} == jupyter ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi

cat >> /usr/local/bin/initialize.sh <<EOF
#!/bin/bash
if ! [ -f /var/bootstraped ];
then
    /etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} > /var/bootstraped 2>&1
fi
EOF

chmod +x /usr/local/bin/initialize.sh 

cat > /etc/systemd/system/initialize.service <<EOF
[Unit]
Description=Make the worker join the k8s cluster
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/initialize.sh 

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable initialize.service 
#cat >> /etc/rc.d/rc.local <<EOF
#if ! [ -f /var/bootstraped ];
#then
#    /etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} > /var/bootstraped 2>&1
#fi
#EOF

shutdown -rf now
