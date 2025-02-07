# Build from root of cloud-automation/ repo:
#   docker build -f Docker/awshelper/Dockerfile 
#
FROM quay.io/cdis/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Ensure correct architecture
RUN dpkg --print-architecture

# Update APT and install dependencies for OpenSSL build
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      wget \
      curl \
      ca-certificates \
      build-essential \
      perl \
      gcc \
      make \
      g++ \
      autoconf \
      automake \
      libtool \
      zlib1g-dev \
      sudo \
      git

# Compile OpenSSL 3.4.0 from source with FIPS enabled (Silent Build)
WORKDIR /usr/local/src

RUN wget -q https://www.openssl.org/source/openssl-3.4.0.tar.gz \
    && tar -xf openssl-3.4.0.tar.gz \
    && cd openssl-3.4.0 \
    && ./Configure enable-fips --prefix=/usr/local/openssl-3.4 --openssldir=/usr/local/openssl-3.4/ssl > /dev/null 2>&1 \
    && make -s -j$(nproc) > /dev/null 2>&1 \
    && make -s install > /dev/null 2>&1 \
    && rm -rf /usr/local/src/openssl-3.4.0 /usr/local/src/openssl-3.4.0.tar.gz

# Remove system-provided OpenSSL to avoid conflicts
RUN apt-get remove -y libssl3 libcrypto3 openssl || true

# Ensure correct architecture and create proper symlinks for OpenSSL 3.4
RUN arch=$(dpkg --print-architecture) \
    && if [ "$arch" = "amd64" ]; then \
          ln -sf /usr/local/openssl-3.4/lib64/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3 \
          && ln -sf /usr/local/openssl-3.4/lib64/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3; \
       elif [ "$arch" = "arm64" ]; then \
          ln -sf /usr/local/openssl-3.4/lib64/libcrypto.so.3 /lib/aarch64-linux-gnu/libcrypto.so.3 \
          && ln -sf /usr/local/openssl-3.4/lib64/libssl.so.3 /lib/aarch64-linux-gnu/libssl.so.3; \
       else \
          echo "Unsupported architecture: $arch" && exit 1; \
       fi \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl \
    && ldconfig \
    && ldd /usr/bin/openssl > /dev/null 2>&1

# Ensure the OpenSSL shared libraries are detected
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib64:$LD_LIBRARY_PATH"

# Initialize FIPS module and install FIPS configuration (Minimal Logging)
RUN /usr/bin/openssl fipsinstall -out /usr/local/openssl-3.4/ssl/fipsmodule.cnf \
    -module /usr/local/openssl-3.4/lib64/ossl-modules/fips.so > /dev/null 2>&1

# Configure OpenSSL for FIPS mode
RUN cp /usr/local/openssl-3.4/ssl/openssl.cnf /usr/local/openssl-3.4/ssl/openssl.cnf.bak \
    && echo "openssl_conf = openssl_init" > /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo ".include fipsmodule.cnf" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && cat /usr/local/openssl-3.4/ssl/openssl.cnf.bak >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "[openssl_init]" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "providers = provider_sect" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "[provider_sect]" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "default = default_sect" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "fips = fips_sect" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "[default_sect]" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "activate = 1" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "[fips_sect]" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "activate = 1" >> /usr/local/openssl-3.4/ssl/openssl.cnf \
    && echo "module = /usr/local/openssl-3.4/lib/ossl-modules/fips.so" >> /usr/local/openssl-3.4/ssl/openssl.cnf

# Detect system library path dynamically
RUN LIB_PATH=$(ldconfig -p | grep libcrypto.so.3 | awk '{print $NF}' | xargs dirname || echo "/lib") \
    && echo "Using system library path: $LIB_PATH" \
    && ln -sf /usr/local/openssl-3.4/lib/libcrypto.so.3 $LIB_PATH/libcrypto.so.3 \
    && ln -sf /usr/local/openssl-3.4/lib/libssl.so.3 $LIB_PATH/libssl.so.3 \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl \
    && ldconfig \
    && ldd /usr/bin/openssl

# Verify FIPS Mode
RUN /usr/bin/openssl list -providers \
    && /usr/bin/openssl version -a
# Install the remaining system dependencies
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      apt-utils \
      apt-transport-https \
      bash-completion \
      curl \
      dnsutils \
      ftp \
      gcc \
      git \
      groff-base \
      iputils-ping \
      jq \
      less \
      libpq-dev \
      lsb-release \
      netcat-openbsd \
      networkd-dispatcher \
      net-tools \
      openssh-client \
      openssh-server \
      python3 \
      python3-dev \
      python3-pip \
      python3-setuptools \
      ssh \
      sudo \
      tmux \
      unzip \
      vim \
      wget \
      gettext-base

#can remove once https://github.com/yaml/pyyaml/issues/724 is solved
RUN pip install pyyaml==6.0.1 --break-system-packages

# RUN  python3 -m pip install pip --upgrade --break-system-packages
RUN  python3 -m pip install --upgrade setuptools --break-system-packages \
    && python3 -m pip install -U crcmod --break-system-packages \
    && python3 -m pip install --upgrade yq --break-system-packages \
    && python3 -m pip install --upgrade 'gen3>4' --break-system-packages

# aws cli v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && /bin/rm -rf awscliv2.zip ./aws

# Ensure gnupg is installed before adding keys
RUN apt-get update && apt-get install -y --no-install-recommends gnupg curl

# Add the Google Cloud SDK repository key and install kubectl
RUN export CLOUD_SDK_REPO="cloud-sdk" \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /usr/share/keyrings/cloud.google.gpg > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends kubectl nodejs \
    && rm -rf /var/lib/apt/lists/*

# Verify installation
RUN kubectl version --client

# Install postgres 13 client
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc| gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y postgresql-client-13

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.31/terraform_0.12.31_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /tmp && mv /tmp/terraform /usr/local/bin/terraform12 && /bin/rm /tmp/terraform.zip

RUN echo "ubuntu:gen3" | chpasswd

# Setup scripts to run sshd for wetty - see kube/services/tty
RUN mkdir -p /opt/usersshd \
    && chown -R ubuntu: /opt/usersshd \
    && chmod -R a+rwX /run

RUN mkdir /var/run/sshd \
  && touch /var/log/lastlog \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 100 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 100 \
  && [ "Python 3" = "$(python --version | awk -F . '{ print $1 }')" ]

EXPOSE 2222

#-------------

USER ubuntu
WORKDIR /home/ubuntu

#
# install and set up gen3
#
COPY --chown=ubuntu:ubuntu . cloud-automation/

# COPY generates files owned by root regardless of USER
RUN /bin/rm -rf ./cloud-automation/node_modules

RUN cp cloud-automation/Docker/awshelper/sshdStart.sh /opt/usersshd/ \
    && cp cloud-automation/Docker/awshelper/sshd_config /opt/usersshd/

RUN cd ./cloud-automation \
    && cat ./Docker/awshelper/bashrc_suffix.sh >> ~/.bashrc

RUN export DEB_PYTHON_INSTALL_LAYOUT=deb && export POETRY_VERSION=1.1.15 && curl -sSL https://install.python-poetry.org | python3 -

RUN git config --global user.email gen3 \
    && git config --global user.name gen3

# smoke test
RUN export GEN3_HOME="$HOME/cloud-automation" \
    && bash -c 'source "$GEN3_HOME/gen3/gen3setup.sh" && gen3 help'

CMD /bin/bash
