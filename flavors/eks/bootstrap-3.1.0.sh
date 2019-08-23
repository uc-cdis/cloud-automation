#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

# Upper case variables are local, lower case are handled by terraform.

if [ ${kernel} != "N/A" ];
then
  S3_LOCATION="s3://gen3-kernels/${kernel}"
else
  S3_LOCATION="s3://gen3-kernels/4.19.30"
fi

KERNEL_FILES="/tmp/gen3-kernel/"



# Let's put our keys on the workers for troubleshooting 
cat > /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO
cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/authorized_keys



# Increasing this for issues related to too many files opened 
sudo sysctl fs.inotify.max_user_watches=12000



# CSOC proxy routing
PROXY="http://csoc-cloud-proxy.internal.io:3128"

if ! [ -d /etc/systemd/system/docker.service.d ];
then
    sudo mkdir -p /etc/systemd/system/docker.service.d
fi

cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY" "HTTPS_PROXY=$PROXY" "NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,.planx-pla.net,.amazonaws.com,.amazon.com"
EOF


echo "export HTTP_PROXY=$PROXY" |sudo tee -a /etc/sysconfig/docker
echo "export HTTPS_PROXY=$PROXY" |sudo tee -a /etc/sysconfig/docker
echo "export NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal.io,.planx-pla.net,.amazonaws.com,.amazon.com" |sudo tee -a /etc/sysconfig/docker


# reload docker for our changes to take place
systemctl daemon-reload
systemctl restart docker





# If we are using this bootstrap is because we want a new kernel on our workers
mkdir $KERNEL_FILES

# Using `aws s3 sync` throws all kind of issues in the logs, using cp instead. 

aws s3 cp --recursive $S3_LOCATION $KERNEL_FILES

rpm -iUv $KERNEL_FILES/kernel*.rpm



# When the host is back up after reboot, it should trigger the eks/bootstrap script for it to join th cluster.

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
    /etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} --apiserver-endpoint ${eks_endpoint} --b64-cluster-ca ${eks_ca} > /var/bootstraped 2>&1
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


#chmod +x /etc/rc.d/rc.local
#cat >> /etc/rc.d/rc.local <<EOF
#if ! [ -f /var/bootstrapted ];
#then
#    /etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} > /var/bootstrapted 2>&1
#fi
#EOF

shutdown -rf now

