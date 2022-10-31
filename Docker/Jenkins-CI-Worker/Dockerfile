FROM jenkins/jnlp-slave:4.13.3-1

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python
RUN set -xe && apt-get update  && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip python3-venv build-essential zip unzip jq less vim gettext-base

RUN set -xe && apt-get update \
  && apt-get install -y lsb-release \
     apt-transport-https \
     ca-certificates  \
     curl \
     gnupg2 \
     libffi-dev \
     libssl-dev \
     libghc-regex-pcre-dev \
     linux-headers-amd64 \
     libcurl4-openssl-dev \
     libncurses5-dev \
     libncursesw5-dev \
     libreadline-dev \
     libsqlite3-dev \
     libgdbm-dev \
     libdb5.3-dev \
     libbz2-dev \
     libexpat1-dev \
     liblzma-dev \
     python-virtualenv \
     lua5.3 \
     r-base \
     software-properties-common \
     sudo \
     tk-dev \
     zlib1g-dev \
     zsh \
     ca-certificates-java \
     openjdk-11-jre-headless \
  && ln -s /usr/bin/lua5.3 /usr/local/bin/lua

# Use jdk11
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
ENV PATH="$JAVA_HOME/bin:$PATH"

COPY ./certfix.sh /certfix.sh
RUN chmod +x /certfix.sh
RUN bash /certfix.sh

# install google tools
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl

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
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get update && apt-get install -y nodejs

# add psql: https://www.postgresql.org/download/linux/debian/
RUN DISTRO="$(lsb_release -c -s)"  \
      && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${DISTRO}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y postgresql-client-13 libpq-dev \
      && rm -rf /var/lib/apt/lists/*

# Copy sh script responsible for installing Python
COPY install-python3.8.sh /root/tmp/install-python3.8.sh

# Run the script responsible for installing Python 3.8.0 and link it to /usr/bin/python
RUN chmod +x /root/tmp/install-python3.8.sh; sync && \
	bash /root/tmp/install-python3.8.sh && \
	rm -rf /root/tmp/install-python3.8.sh && \
        unlink /usr/bin/python3 && \
        ln -s /usr/local/bin/python3.8 /usr/bin/python3

# Fix shebang for lsb_release
RUN sed -i 's/python3/python3.8/' /usr/bin/lsb_release && \
    sed -i 's/python3/python3.8/' /usr/bin/add-apt-repository

# install aws cli, poetry, pytest, etc.
RUN set -xe && python3.8 -m pip install awscli --upgrade && python3.8 -m pip install pytest --upgrade && python3.8 -m pip install poetry && python3.8 -m pip install PyYAML --upgrade && python3.8 -m pip install lxml --upgrade && python3.8 -m pip install yq --upgrade && python3.8 -m pip install datadog --upgrade

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3.8 -

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.31/terraform_0.12.31_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /tmp && mv /tmp/terraform /usr/local/bin/terraform12 && /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

# Install google chrome
RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64]  http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get -y update \
    && apt-get -y install google-chrome-stable

# update /etc/sudoers
RUN sed 's/^%sudo/#%sudo/' /etc/sudoers > /etc/sudoers.bak \
  && /bin/echo -e "\n%sudo    ALL=(ALL:ALL) NOPASSWD:ALL\n" >> /etc/sudoers.bak \
  && cp /etc/sudoers.bak /etc/sudoers \
  && usermod -G sudo jenkins

USER jenkins

RUN git config --global user.email jenkins \
    && git config --global user.name jenkins

