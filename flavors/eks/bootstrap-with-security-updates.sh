#!/bin/bash -xe

# User data for our EKS worker nodes basic arguments to call the bootstrap script for EKS images 
# More info https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

cat >> /home/ec2-user/.ssh/authorized_keys <<EFO
${ssh_keys}
EFO

sysctl -w fs.inotify.max_user_watches=12000

KUBELET_EXTRA_ARGUMENTS="--node-labels=role=${nodepool},eks.amazonaws.com/capacityType=${lifecycle_type}"

if [[ ${nodepool} != default ]];
then
    KUBELET_EXTRA_ARGUMENTS="$KUBELET_EXTRA_ARGUMENTS --register-with-taints=role=${nodepool}:NoSchedule"
fi
/etc/eks/bootstrap.sh --kubelet-extra-args "$KUBELET_EXTRA_ARGUMENTS" ${vpc_name} --apiserver-endpoint ${eks_endpoint} --b64-cluster-ca ${eks_ca}



## Ensure source routed packets are not accepted
sysctl -w net.ipv4.conf.all.accept_source_route=0
sysctl -w net.ipv4.conf.default.accept_source_route=0
sysctl -w net.ipv6.conf.all.accept_source_route=0
sysctl -w net.ipv6.conf.default.accept_source_route=0
sysctl -w net.ipv4.route.flush=1
sysctl -w net.ipv6.route.flush=1


## Ensure Reverse Path Filtering is enabled
sysctl -w net.ipv4.conf.all.rp_filter=1
sysctl -w net.ipv4.conf.default.rp_filter=1
sysctl -w net.ipv4.route.flush=1


## Ensure SSH Protocol is set to 2
echo "Protocol 2" >> /etc/ssh/sshd_config

## Ensure SSH root login is disabled
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

## Ensure only strong ciphers are used
echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config

## Ensure only strong MAC algorithms are used
echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config

## Ensure that strong Key Exchange algorithms are used
echo "KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config

## Ensure SSH Idle Timeout Interval is configured
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config


## Ensure filesystem integrity is regularly checked
## Ensure updates, patches, and additional security software are installed 
yum -y update --security
yum -y install aide

cat > /etc/cron.daily/filesystem_integrity <<EOF
#!/bin/bash
$(command -v aide) --check
EOF
chmod +x /etc/cron.daily/filesystem_integrity 

$(command -v aide) --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Install qualys agent if the activtion and customer id provided
if [[ ! -z "${activation_id}" ]] || [[ ! -z "${customer_id}" ]]; then
    aws s3 cp s3://qualys-agentpackage/QualysCloudAgent.rpm ./qualys-cloud-agent.x86_64.rpm
    sudo rpm -ivh qualys-cloud-agent.x86_64.rpm
    # Clean up rpm package after install
    rm qualys-cloud-agent.x86_64.rpm
    sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=${activation_id} CustomerId=${customer_id}
fi

docker run --privileged --rm tonistiigi/binfmt --install all