FROM jenkins/jenkins:2.126

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python and pip and aws cli
RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip build-essential zip unzip jq less vim gettext-base
RUN set -xe && python -m pip install awscli --upgrade && python -m pip install pytest --upgrade && python -m pip install PyYAML --upgrade
RUN set -xe && python3 -m pip install pytest --upgrade && python3 -m pip install PyYAML --upgrade

RUN apt-get update \
  && apt-get install -y lsb-release \
     apt-transport-https \
     r-base

RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl \
          zsh

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

# install r packages
RUN Rscript -e 'install.packages("yaml",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("curl",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("httr",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("stringr",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("pryr",repos="http://cran.us.r-project.org");'

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/sbin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins
