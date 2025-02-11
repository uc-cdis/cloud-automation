# Use Ubuntu 24.04 base image
FROM quay.io/cdis/ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required for OpenSSL compilation
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
      lsb-release \
      bc vim \
    > /dev/null 2>&1


# Set working directory for OpenSSL source
WORKDIR /usr/local/src


RUN wget https://raw.githubusercontent.com/ajoaugustine/redis-conf/refs/heads/master/openssl.cnf

# Download, compile, and install OpenSSL 3.4 with FIPS support,
# forcing libraries into /usr/local/openssl-3.4/lib via --libdir=lib
RUN wget https://www.openssl.org/source/openssl-3.4.0.tar.gz && \
    tar -xf openssl-3.4.0.tar.gz && \
    cd openssl-3.4.0 && \
    export LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib:${LD_LIBRARY_PATH:-}" && \
    ./Configure enable-fips --prefix=/usr/local/openssl-3.4 --openssldir=/usr/local/openssl-3.4/ssl --libdir=lib && \
    make -j$(nproc) > /dev/null 2>&1 && \
    make install > /dev/null 2>&1 
    # rm -rf /usr/local/src/openssl-3.4.0 /usr/local/src/openssl-3.4.0.tar.gz

# Remove system-provided OpenSSL to prevent conflicts
RUN apt-get remove -y libssl3 libcrypto3 openssl || true

# Detect OpenSSL's shared library directory dynamically and create symlinks
RUN export LIB_PATH=$(ldconfig -p | grep libcrypto.so.3 | awk '{print $NF}' | xargs dirname || echo "/lib") && \
    echo "Using detected OpenSSL library path: $LIB_PATH" && \
    ln -sf /usr/local/openssl-3.4/lib/libcrypto.so.3 $LIB_PATH/libcrypto.so.3 && \
    ln -sf /usr/local/openssl-3.4/lib/libssl.so.3 $LIB_PATH/libssl.so.3 && \
    ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl && \
    ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl && \
    ldconfig

# Ensure the OpenSSL shared libraries are detected
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib:${LD_LIBRARY_PATH:-}"

# Determine and set the OpenSSL config directory.
# (The typical output of `openssl version -d` is: OPENSSLDIR: "/usr/local/openssl-3.4/ssl")
# We set it as an ENV variable so it persists across RUN steps.
ENV OPENSSL_CONFIG_DIR="/usr/local/openssl-3.4/ssl"

# Automatically detect FIPS module path and install the FIPS module.
# (If fips.so is not in $OPENSSL_CONFIG_DIR/ossl-modules, attempt to copy it from /usr/local/openssl-3.4/lib/ossl-modules)
RUN export FIPS_MODULE_DIR=$(/usr/local/openssl-3.4/bin/openssl version -d | awk -F'"' '{print $2}')/ossl-modules && \
    echo "Detected FIPS module directory: $FIPS_MODULE_DIR" && \
    if [ ! -f "$FIPS_MODULE_DIR/fips.so" ]; then \
        echo "fips.so not found in $FIPS_MODULE_DIR, attempting to copy from /usr/local/openssl-3.4/lib/ossl-modules"; \
        mkdir -p "$FIPS_MODULE_DIR"; \
        cp /usr/local/openssl-3.4/lib/ossl-modules/fips.so "$FIPS_MODULE_DIR/fips.so"; \
    fi && \
    /usr/local/openssl-3.4/bin/openssl fipsinstall -out $OPENSSL_CONFIG_DIR/fipsmodule.cnf -module $FIPS_MODULE_DIR/fips.so


# Rewrite OpenSSL configuration for FIPS mode 
RUN cp /usr/local/src/openssl_cnf /usr/local/openssl-3.4/ssl/openssl.cnf

# Verify OpenSSL version and FIPS provider configuration
# RUN openssl version -a
# RUN openssl list -providers

# Set default command to launch an interactive shell
CMD ["/bin/bash"]
