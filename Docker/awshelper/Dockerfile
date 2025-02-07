# Build from root of cloud-automation/ repo:
#   docker build -f Docker/awshelper/Dockerfile 
#
FROM quay.io/cdis/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Ensure correct architecture
RUN dpkg --print-architecture

# Update APT and install dependencies (BEFORE OpenSSL Upgrade)
RUN apt-get update -qq && apt-get upgrade -y -qq \
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
      git \
      python3 \
      python3-dev \
      python3-pip \
      python3-setuptools \
      unzip \
      gnupg \
      > /dev/null 2>&1

# Install Poetry FIRST to Avoid SSL Issues
RUN export DEB_PYTHON_INSTALL_LAYOUT=deb \
    && export POETRY_VERSION=1.1.15 \
    && curl -sSL https://install.python-poetry.org | python3 - > /dev/null 2>&1

# Install AWS CLI v2 (Silent)
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install > /dev/null 2>&1 \
    && /bin/rm -rf awscliv2.zip ./aws

# Add the Google Cloud SDK repository key and install kubectl (Silent)
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends kubectl nodejs > /dev/null 2>&1 \
    && rm -rf /var/lib/apt/lists/*

# Install Postgres 13 client (Silent)
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list > /dev/null \
    && apt-get update -qq \
    && apt-get install -y postgresql-client-13 > /dev/null 2>&1

# Install Terraform (Silent)
RUN curl -s -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip \
   && unzip -q /tmp/terraform.zip -d /usr/local/bin \
   && /bin/rm /tmp/terraform.zip

RUN curl -s -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.31/terraform_0.12.31_linux_amd64.zip \
   && unzip -q /tmp/terraform.zip -d /tmp \
   && mv /tmp/terraform /usr/local/bin/terraform12 \
   && /bin/rm /tmp/terraform.zip

# Configure SSH (Silent)
RUN echo "ubuntu:gen3" | chpasswd \
    && mkdir -p /opt/usersshd \
    && chown -R ubuntu: /opt/usersshd \
    && chmod -R a+rwX /run

RUN mkdir /var/run/sshd \
  && touch /var/log/lastlog \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 100 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 100 > /dev/null 2>&1

EXPOSE 2222

#-------------

USER ubuntu
WORKDIR /home/ubuntu

#
# Install and Set Up Gen3
#
COPY --chown=ubuntu:ubuntu . cloud-automation/

# Remove node_modules (if exists)
RUN /bin/rm -rf ./cloud-automation/node_modules

RUN cp cloud-automation/Docker/awshelper/sshdStart.sh /opt/usersshd/ \
    && cp cloud-automation/Docker/awshelper/sshd_config /opt/usersshd/

RUN cd ./cloud-automation \
    && cat ./Docker/awshelper/bashrc_suffix.sh >> ~/.bashrc

# Set SSL certificate paths BEFORE OpenSSL installation
USER root
RUN apt-get update -qq && apt-get install -y --no-install-recommends ca-certificates \
    > /dev/null 2>&1 || (echo "CA CERTIFICATES UPDATE FAILED" && exit 1)

USER ubuntu
WORKDIR /home/ubuntu

# Configure Git BEFORE OpenSSL upgrade
RUN git config --global http.sslVerify true

#---------------#
# OpenSSL Install (Moved to END to Avoid SSL Issues)
#---------------#
USER root
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
    && ln -sf /usr/local/openssl-3.4/lib64/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3 \
    && ln -sf /usr/local/openssl-3.4/lib64/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3 \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl \
    && ldconfig > /dev/null 2>&1

# Ensure the OpenSSL shared libraries are detected
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib64:$LD_LIBRARY_PATH"

# Initialize FIPS module and install FIPS configuration
RUN /usr/bin/openssl fipsinstall -out /usr/local/openssl-3.4/ssl/fipsmodule.cnf \
    -module /usr/local/openssl-3.4/lib64/ossl-modules/fips.so > /dev/null 2>&1

# Verify OpenSSL and FIPS mode (Silent)
RUN /usr/bin/openssl version -a > /dev/null 2>&1

#------------#
# Smoke Test
#------------#
USER ubuntu
WORKDIR /home/ubuntu

RUN export GEN3_HOME="$HOME/cloud-automation" \
    && bash -c 'source "$GEN3_HOME/gen3/gen3setup.sh" && gen3 help' > /dev/null 2>&1

CMD /bin/bash
