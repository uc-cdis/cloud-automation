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
      lsb-release \
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

# Set SSL certificate paths BEFORE OpenSSL installation
USER root
RUN apt-get update -qq && apt-get install -y --no-install-recommends ca-certificates \
    > /dev/null 2>&1 || (echo "CA CERTIFICATES UPDATE FAILED" && exit 1)

USER ubuntu
WORKDIR /home/ubuntu

#---------------#
# OpenSSL Install (Generic & FIPS-Enabled)
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

# Ensure OpenSSL 3.4 is installed correctly
RUN ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl \
    && ldconfig > /dev/null 2>&1

# Ensure the OpenSSL shared libraries are detected
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib64:$LD_LIBRARY_PATH"

# Initialize FIPS module and install FIPS configuration (Explicit Path)
RUN /usr/local/openssl-3.4/bin/openssl fipsinstall -out /usr/local/openssl-3.4/ssl/fipsmodule.cnf \
    -module /usr/local/openssl-3.4/lib64/ossl-modules/fips.so > /dev/null 2>&1

# Fix OpenSSL Configuration for FIPS Mode
RUN cp /usr/local/openssl-3.4/ssl/openssl.cnf /usr/local/openssl-3.4/ssl/openssl.cnf.bak \
    && sed -i '/^\# fips = fips_sect$/s/^# //' /usr/local/openssl-3.4/ssl/openssl.cnf \
    && sed -i '/^\# \.include fipsmodule.cnf$/s/^# //' /usr/local/openssl-3.4/ssl/openssl.cnf

# Verify OpenSSL and FIPS mode
RUN /usr/local/openssl-3.4/bin/openssl version -a \
    && /usr/local/openssl-3.4/bin/openssl list -providers

#------------#
USER ubuntu
WORKDIR /home/ubuntu

RUN export GEN3_HOME="$HOME/cloud-automation" \
    && bash -c 'source "$GEN3_HOME/gen3/gen3setup.sh" && gen3 help' > /dev/null 2>&1

CMD /bin/bash
