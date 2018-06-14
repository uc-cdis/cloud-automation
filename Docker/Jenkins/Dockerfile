FROM jenkins/jenkins:2.116

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python and pip and aws cli
RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip build-essential zip unzip jq less vim gettext-base && rm -rf /var/lib/apt/lists/*
RUN set -xe && pip install awscli --upgrade && pip install pytest --upgrade && pip install PyYAML --upgrade
RUN set -xe && pip3 install pytest --upgrade

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs

# install chrome (supports headless mode)
RUN set -xe \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip
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
