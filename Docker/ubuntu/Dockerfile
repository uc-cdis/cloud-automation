# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Prevent interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive

# Update system and install dependencies (including ca-certificates)
RUN apt-get update -qq && apt-get upgrade -y -qq && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
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
        vim \
        lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Set working directory for downloading sources
WORKDIR /usr/local/src

# Download the custom OpenSSL configuration file and OpenSSL source tarball
RUN wget https://raw.githubusercontent.com/ajoaugustine/redis-conf/refs/heads/master/openssl_cnf && \
    wget https://www.openssl.org/source/openssl-3.4.0.tar.gz

# Extract the OpenSSL tarball
RUN tar -xf openssl-3.4.0.tar.gz

# Change directory to the extracted OpenSSL source
WORKDIR /usr/local/src/openssl-3.4.0

# Remove any pre-installed OpenSSL libraries to avoid conflicts
RUN apt-get remove -y libssl3 openssl libcrypto3 || true

# Configure, compile, and install OpenSSL 3.4 with FIPS support
RUN ./Configure enable-fips --prefix=/usr/local/openssl-3.4 --openssldir=/usr/local/openssl-3.4/ssl --libdir=lib 2> /dev/null && \
    make -s -j$(nproc) && \
    make install 1> /dev/null

# Update the OpenSSL configuration file with our custom configuration file
RUN cp /usr/local/src/openssl_cnf /usr/local/openssl-3.4/ssl/openssl.cnf

# Update dynamic linker configuration so the new OpenSSL libraries are found
RUN echo "/usr/local/openssl-3.4/lib" > /etc/ld.so.conf.d/openssl-3.4.conf && ldconfig

# Set environment variables so that the new OpenSSL version is prioritized
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib:${LD_LIBRARY_PATH}"
ENV PATH="/usr/local/openssl-3.4/bin:${PATH}"
ENV OPENSSL_CONF="/usr/local/openssl-3.4/ssl/openssl.cnf"

# Update root's .bashrc so that interactive shells also load these variables
RUN echo 'export LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib:$LD_LIBRARY_PATH"' >> /root/.bashrc && \
    echo 'export PATH="/usr/local/openssl-3.4/bin:$PATH"' >> /root/.bashrc && \
    echo 'export OPENSSL_CONF="/usr/local/openssl-3.4/ssl/openssl.cnf"' >> /root/.bashrc

# Set the working directory to where OpenSSL is installed
WORKDIR /usr/local/openssl-3.4/ssl

# Check and rename existing certs and private directories, then create the links
RUN [ -d certs ] && mv certs certs.old || true && \
    [ -d private ] && mv private private.old || true && \
    ln -s /etc/ssl/certs certs && \
    ln -s /etc/ssl/private private

# Create symbolic links for the configuration files in /etc/ssl
RUN [ -f /etc/ssl/openssl.cnf ] && mv /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.bak || true && \
    [ -f /etc/ssl/fipsmodule.cnf ] && mv /etc/ssl/fipsmodule.cnf /etc/ssl/fipsmodule.cnf.bak || true && \
    ln -s /usr/local/openssl-3.4/ssl/openssl.cnf /etc/ssl/openssl.cnf && \
    ln -s /usr/local/openssl-3.4/ssl/fipsmodule.cnf /etc/ssl/fipsmodule.cnf

# (Optional) Verify the installation. These commands are run and any errors are ignored,
# so the build doesn't fail if verification fails.
RUN openssl version -a || true && \
    openssl list -providers || true

# Use bash as the default shell
CMD ["/bin/bash"]
