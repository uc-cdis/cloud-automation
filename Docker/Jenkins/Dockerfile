FROM quay.io/cdis/dockerhubjenkins/jenkins:2.273

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y lsb-release \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     libffi-dev \
     libssl-dev \
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
  && ln -s /usr/bin/lua5.3 /usr/local/bin/lua

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -

# install google tools
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl

# Copy sh script responsible for installing Python
COPY install-python3.8.sh /root/tmp/install-python3.8.sh

# Run the script responsible for installing Python 3.8.0 and link it to /usr/bin/python
RUN chmod +x /root/tmp/install-python3.8.sh; sync && \
	./root/tmp/install-python3.8.sh && \
	rm -rf /root/tmp/install-python3.8.sh && \
        unlink /usr/bin/python && \
        unlink /usr/bin/python3 && \
	ln -s /Python-3.8.0/python /usr/bin/python && \
        ln -s /Python-3.8.0/python /usr/bin/python3 && \
        ln -s /usr/bin/lsb_release /usr/local/lib/python3.8/site-packages/lsb_release.py

# reconfigure lsb_release
RUN apt-get reinstall -y lsb-release

# Install pip3 for Python 3.8.0
RUN rm -rf /usr/local/lib/python3.8/site-packages/pip* && \
	wget https://bootstrap.pypa.io/get-pip.py && \
	python3.8 get-pip.py && \
	rm get-pip.py

# install python and pip and aws cli
RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils build-essential zip unzip jq less vim gettext-base
RUN set -xe && python -m pip install awscli --upgrade && python -m pip install pytest --upgrade && python -m pip install PyYAML --upgrade && python -m pip install lxml --upgrade
RUN set -xe && python -m pip install yq --upgrade

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -

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

# install chrome (supports headless mode)
RUN set -xe \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /tmp && mv /tmp/terraform /usr/local/bin/terraform12 && /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

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
      && apt-get install -y postgresql-client-9.6 libpq-dev \
      && rm -rf /var/lib/apt/lists/*

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/sbin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins

RUN git config --global user.email jenkins \
    && git config --global user.name jenkins
