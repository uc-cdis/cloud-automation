FROM jenkins/jenkins:2.95

USER root

ENV DEBIAN_FRONTEND=noninteractive
# install python and pip and aws cli
RUN apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev build-essential zip unzip jq less && rm -rf /var/lib/apt/lists/*
RUN easy_install pip
RUN pip install awscli --upgrade

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip
RUN unzip /tmp/terraform.zip -d /usr/local/bin; /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.1.2/packer_1.1.2_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

# install kubectl
RUN wget -P /tmp https://dl.k8s.io/v1.7.10/kubernetes-client-linux-amd64.tar.gz
RUN tar xvfz /tmp/kubernetes-client-linux-amd64.tar.gz -C /tmp
RUN chmod -R a+rX /tmp/kubernetes/client/bin && mv /tmp/kubernetes/client/bin/kube* /usr/local/bin/
RUN rm -r /tmp/kubernetes /tmp/kubernetes-client-linux-amd64.tar.gz

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/bin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins
