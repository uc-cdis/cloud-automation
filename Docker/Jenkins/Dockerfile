FROM jenkins/jenkins:2.113

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python and pip and aws cli
RUN apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip build-essential zip unzip jq less && rm -rf /var/lib/apt/lists/*
RUN pip install awscli --upgrade && pip install pytest --upgrade
RUN pip3 install pytest --upgrade

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.3/terraform_0.11.3_linux_amd64.zip
RUN unzip /tmp/terraform.zip -d /usr/local/bin; /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.2.1/packer_1.2.1_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

# install kubectl
RUN wget -P /tmp https://dl.k8s.io/v1.7.10/kubernetes-client-linux-amd64.tar.gz
RUN tar xvfz /tmp/kubernetes-client-linux-amd64.tar.gz -C /tmp
RUN chmod -R a+rX /tmp/kubernetes/client/bin && mv /tmp/kubernetes/client/bin/kube* /usr/local/bin/
RUN rm -r /tmp/kubernetes /tmp/kubernetes-client-linux-amd64.tar.gz

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/sbin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins
