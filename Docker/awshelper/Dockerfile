# Start from Ubuntu 24.04 base image
FROM quay.io/cdis/ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required for OpenSSL compilation
RUN apt-get update -qq && apt-get upgrade -y -qq \
    && apt-get install -y --no-install-recommends \
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
      > /dev/null 2>&1

# Set working directory for OpenSSL source
WORKDIR /usr/local/src

# Download, compile, and install OpenSSL 3.4 with FIPS support
RUN wget -q https://www.openssl.org/source/openssl-3.4.0.tar.gz \
    && tar -xf openssl-3.4.0.tar.gz \
    && cd openssl-3.4.0 \
    && ./Configure enable-fips --prefix=/usr/local/openssl-3.4 --openssldir=/usr/local/openssl-3.4/ssl > /dev/null 2>&1 \
    && make -s -j$(nproc) > /dev/null 2>&1 \
    && make -s install > /dev/null 2>&1 \
    && rm -rf /usr/local/src/openssl-3.4.0 /usr/local/src/openssl-3.4.0.tar.gz

# Remove system-provided OpenSSL to prevent conflicts
RUN apt-get remove -y libssl3 libcrypto3 openssl || true

# Detect OpenSSL's shared library directory dynamically
RUN export LIB_PATH=$(ldconfig -p | grep libcrypto.so.3 | awk '{print $NF}' | xargs dirname || echo "/lib") \
    && echo "Using detected OpenSSL library path: $LIB_PATH" \
    && ln -sf /usr/local/openssl-3.4/lib64/libcrypto.so.3 $LIB_PATH/libcrypto.so.3 \
    && ln -sf /usr/local/openssl-3.4/lib64/libssl.so.3 $LIB_PATH/libssl.so.3 \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/openssl-3.4/bin/openssl /usr/local/bin/openssl \
    && ldconfig > /dev/null 2>&1

# Ensure the OpenSSL shared libraries are detected
ENV LD_LIBRARY_PATH="/usr/local/openssl-3.4/lib64:$LD_LIBRARY_PATH"

# Automatically Detect OpenSSL's Default Config Directory
RUN export OPENSSL_CONFIG_DIR=$(/usr/local/openssl-3.4/bin/openssl version -d | awk -F'"' '{print $2}') \
    && echo "Detected OpenSSL config directory: $OPENSSL_CONFIG_DIR"

# Automatically Detect OpenSSL's FIPS Module Path
RUN export FIPS_MODULE_DIR=$(/usr/local/openssl-3.4/bin/openssl version -d | awk -F'"' '{print $2}')/ossl-modules \
    && echo "Detected FIPS module directory: $FIPS_MODULE_DIR" \
    && /usr/local/openssl-3.4/bin/openssl fipsinstall -out $OPENSSL_CONFIG_DIR/fipsmodule.cnf \
       -module $FIPS_MODULE_DIR/fips.so > /dev/null 2>&1

# Fix OpenSSL Configuration for FIPS Mode (No Hardcoded Paths)
RUN cp $OPENSSL_CONFIG_DIR/openssl.cnf $OPENSSL_CONFIG_DIR/openssl.cnf.bak \
    && sed -i '/^\# fips = fips_sect$/s/^# //' $OPENSSL_CONFIG_DIR/openssl.cnf \
    && sed -i '/^\# \.include fipsmodule.cnf$/s/^# //' $OPENSSL_CONFIG_DIR/openssl.cnf \
    && echo "[fips_sect]" >> $OPENSSL_CONFIG_DIR/openssl.cnf \
    && echo "activate = 1" >> $OPENSSL_CONFIG_DIR/openssl.cnf \
    && echo "module = $FIPS_MODULE_DIR/fips.so" >> $OPENSSL_CONFIG_DIR/openssl.cnf

# Verify OpenSSL and FIPS mode
RUN /usr/local/openssl-3.4/bin/openssl version -a \
    && /usr/local/openssl-3.4/bin/openssl list -providers

CMD ["/bin/bash"]
