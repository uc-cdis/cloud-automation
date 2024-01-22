FROM jenkins/inbound-agent:jdk21

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils build-essential zip unzip jq less vim gettext-base

RUN apt-get update \
  && apt-get install -y lsb-release \
      git \
     apt-transport-https \
     r-base \
     libffi-dev \
     libssl-dev \
     libcurl4-openssl-dev \
     zlib1g-dev \
     libncurses5-dev \
     libncursesw5-dev \
     libreadline-dev \
     libsqlite3-dev \
     libgdbm-dev \
     libdb5.3-dev \
     libbz2-dev \
     libexpat1-dev \
     liblzma-dev \
     tk-dev \
     ca-certificates \
     curl \
     gnupg2 \
     lua5.3 \
     software-properties-common \
     sudo \
     wget \
  && ln -s /usr/bin/lua5.3 /usr/local/bin/lua

# install Ruby.
RUN apt-get install -y ruby-full

#
# install docker tools:
#
RUN sudo install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && sudo chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update && apt-get install -y docker-ce

# install k6 to run load tests
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 \
  && echo "deb https://dl.k6.io/deb stable main" | tee /etc/apt/sources.list.d/k6.list \
  && apt-get update \
  && apt-get install k6
  
# install xk6-browser
RUN cd /opt && wget --quiet https://github.com/grafana/xk6-browser/releases/download/v0.3.0/xk6-browser-v0.3.0-linux-amd64.tar.gz \
  && tar -xvzf /opt/xk6-browser-v0.3.0-linux-amd64.tar.gz
ENV PATH="/opt/xk6-browser-v0.3.0-linux-amd64:${PATH}"

# install google tools
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl \
          zsh

# Install jq 1.6
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x jq-linux64 && mv jq-linux64 /usr/bin/jq

#
# install docker tools:
#
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && /usr/bin/add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian \
    $(lsb_release -c -s) \
    stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod a+rx /usr/local/bin/docker-compose

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get update && apt-get install -y nodejs

# install chrome (supports headless mode)
RUN set -xe \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

# install packer
RUN curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip
RUN unzip /tmp/packer.zip -d /usr/local/bin; /bin/rm /tmp/packer.zip

# add psql: https://www.postgresql.org/download/linux/debian/
RUN DISTRO="$(lsb_release -c -s)"  \
      && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${DISTRO}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet --no-check-certificate -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y postgresql-client-13 libpq-dev \
      && rm -rf /var/lib/apt/lists/*

# Copy sh script responsible for installing Python
COPY install-python3.9.sh /root/tmp/install-python3.9.sh

# Run the script responsible for installing Python 3.9.0 and link it to /usr/bin/python
RUN chmod +x /root/tmp/install-python3.9.sh; sync && \
        bash /root/tmp/install-python3.9.sh && \
        rm -rf /root/tmp/install-python3.9.sh && \
        unlink /usr/bin/python3 && \
        ln -s /usr/local/bin/python3.9 /usr/bin/python && \
        ln -s /usr/local/bin/python3.9 /usr/bin/python3

RUN env
RUN which python
RUN which python3.9

# Fix shebang for lsb_release
RUN sed -i 's/python3/python3.9/' /usr/bin/lsb_release && \
    sed -i 's/python3/python3.9/' /usr/bin/add-apt-repository

# install aws cli, poetry, pytest, etc.
RUN set -xe && python3.9 -m pip install --upgrade pip && python3.9 -m pip install awscli --upgrade && python3.9 -m pip install pytest --upgrade && python3.9 -m pip install poetry && python3.9 -m pip install PyYAML --upgrade && python3.9 -m pip install lxml --upgrade && python3.9 -m pip install yq --upgrade

# update /etc/sudoers
RUN sed 's/^%sudo/#%sudo/' /etc/sudoers > /etc/sudoers.bak \
  && /bin/echo -e "\n%sudo    ALL=(ALL:ALL) NOPASSWD:ALL\n" >> /etc/sudoers.bak \
  && cp /etc/sudoers.bak /etc/sudoers \
  && usermod -G sudo jenkins

USER jenkins

