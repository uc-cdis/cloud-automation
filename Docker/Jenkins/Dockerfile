FROM jenkins/jenkins:2.177

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python and pip and aws cli
RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip build-essential zip unzip jq less vim gettext-base
RUN set -xe && python -m pip install awscli --upgrade && python -m pip install pytest --upgrade && python -m pip install PyYAML --upgrade
RUN set -xe && python3 -m pip install pytest --upgrade && python3 -m pip install PyYAML --upgrade
RUN set -xe && python -m pip install yq --upgrade && python3 -m pip install yq --upgrade

RUN apt-get update \
  && apt-get install -y lsb-release \
     apt-transport-https \
     r-base \
     libssl-dev \
     libcurl4-openssl-dev \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common \
     sudo

# install google tools
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl \
          zsh

#
# install docker tools:
#  * https://docs.docker.com/install/linux/docker-ce/debian/#install-docker-ce-1
#  * https://docs.docker.com/compose/install/#install-compose
#
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" \
   && apt-get update \
   && apt-get install -y docker-ce \
   && curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
   && chmod a+rx /usr/local/bin/docker-compose


# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get update && apt-get install -y nodejs

# install chrome (supports headless mode)
RUN set -xe \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.3.3/packer_1.3.3_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

# install r packages
RUN Rscript -e 'install.packages("yaml",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("curl",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("httr",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("stringr",repos="http://cran.us.r-project.org");' \
    && Rscript -e 'install.packages("pryr",repos="http://cran.us.r-project.org");'

# update /etc/sudoers
RUN sed 's/^%sudo/#%sudo/' /etc/sudoers > /etc/sudoers.bak \
  && /bin/echo -e "\n%sudo    ALL=(ALL:ALL) NOPASSWD:ALL\n" >> /etc/sudoers.bak \
  && cp /etc/sudoers.bak /etc/sudoers \
  && usermod -G sudo jenkins

# add psql: https://www.postgresql.org/download/linux/debian/
RUN DISTRO="$(lsb_release -c -s)"  \
      && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${DISTRO}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y postgresql-client-9.6 \
      && rm -rf /var/lib/apt/lists/*

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/sbin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins
