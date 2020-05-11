# Build from root of cloud-automation/ repo:
#   docker build -f Docker/awshelper/Dockerfile 
#
FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
      apt-utils \
      apt-transport-https \
      curl \
      dnsutils \
      ftp \
      jq \
      less \
      ssh \
      gcc \
      git \
      groff-base \
      iputils-ping \
      lsb-release \
      netcat-openbsd \
      net-tools \
      openssh-client \
      postgresql-client \
      python3 \
      python3-dev \
      python3-pip \
      python3-setuptools \
      sudo \
      unzip \
      vim \
      wget \
      gettext-base

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 100

RUN  python3 -m pip install --upgrade pip \
    && python3 -m pip install --upgrade setuptools \
    && python3 -m pip install -U crcmod \
    && python3 -m pip install awscli --upgrade \
    && python3 -m pip install yq --upgrade

# From  https://hub.docker.com/r/google/cloud-sdk/~/dockerfile/
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
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
    kubectl version --client && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ubuntu
RUN npm install elasticdump -g

WORKDIR /home/ubuntu

#
# install and set up gen3
# Note:
#
COPY . cloud-automation/
RUN /bin/rm -rf ./cloud-automation/node_modules \
    && chown -R ubuntu: ./cloud-automation \
    && chmod u+rwX ./cloud-automation

USER ubuntu
RUN chmod -R u+rwX ./cloud-automation \
    && cd ./cloud-automation \
    && npm ci \
    && echo 'export GEN3_HOME="$HOME/cloud-automation"' >> ~/.bashrc \
    && echo 'export ESHOST=esproxy-service:9200' >> ~/.bashrc \
    && echo 'source "${GEN3_HOME}/gen3/gen3setup.sh"' >> ~/.bashrc 

# smoke test
RUN export GEN3_HOME="$HOME/cloud-automation" \
    && bash -c 'source "$GEN3_HOME/gen3/gen3setup.sh" && gen3 help'

CMD /bin/bash
