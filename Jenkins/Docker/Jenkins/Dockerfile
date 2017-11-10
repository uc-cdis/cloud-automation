FROM jenkins/jenkins:latest

USER root

# install python and pip and aws cli
RUN apt-get update && apt-get install -y python python-setuptools python-dev build-essential zip unzip && rm -rf /var/lib/apt/lists/*
RUN easy_install pip
RUN pip install awscli --upgrade

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.10.8/terraform_0.10.8_linux_amd64.zip
RUN unzip /tmp/terraform.zip -d /usr/local/bin; /bin/rm /tmp/terraform.zip

# install kubectl
RUN wget -P /tmp https://dl.k8s.io/v1.7.10/kubernetes-client-linux-amd64.tar.gz
RUN tar xvfz /tmp/kubernetes-client-linux-amd64.tar.gz -C /tmp
RUN chmod -R a+rX /tmp/kubernetes/client/bin && mv /tmp/kubernetes/client/bin/kube* /usr/local/bin/
RUN rm -r /tmp/kubernetes /tmp/kubernetes-client-linux-amd64.tar.gz

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rX /opt/cdis
ENTRYPOINT ["/bin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins
