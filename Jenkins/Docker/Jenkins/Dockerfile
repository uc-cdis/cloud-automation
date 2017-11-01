FROM jenkins/jenkins:latest

USER root
RUN apt update && apt install -y python python-setuptools python-dev build-essential && rm -rf /var/lib/apt/lists/*
RUN easy_install pip
RUN pip install awscli --upgrade
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.10.8/terraform_0.10.8_linux_amd64.zip
RUN unzip /tmp/terraform.zip -d /usr/local/bin; /bin/rm /tmp/terraform.zip
USER jenkins
