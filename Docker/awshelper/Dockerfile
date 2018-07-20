# To run: docker run -d -v /path/to/local_settings.py:/var/www/fence/local_settings.py --name=fence -p 80:80 fence
# To check running container: docker exec -it fence /bin/bash

FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
      apt-utils \
      apt-transport-https \
      lsb-release \
      curl \
      dnsutils \
      gcc \
      git \
      openssh-client \
      postgresql-client \
      python2.7 \
      python-dev \
      python-pip \
      python-setuptools \
      vim \
      less \
      jq \
      ssh \
      ftp \
      wget \
      netcat-openbsd \
      iputils-ping \
      net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN  easy_install -U pip \
    && python -m pip install --upgrade pip \
    && python -m pip install --upgrade setuptools \
    && python -m pip install -U crcmod \
    && python -m pip install awscli --upgrade \
    && python -m pip install yq --upgrade

# From  https://hub.docker.com/r/google/cloud-sdk/~/dockerfile/
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk \
        google-cloud-sdk-cbt \
        kubectl && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    gcloud --version && \
    kubectl version --client

RUN useradd -m -s /bin/bash ubuntu

WORKDIR /home/ubuntu
USER ubuntu

CMD /bin/bash
