# Build from root of cloud-automation/ repo:
#   docker build -f Docker/awshelper/Dockerfile 
#
FROM quay.io/cdis/ubuntu-fips-base:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
      apt-utils \
      apt-transport-https \
      bash-completion \
      curl \
      dnsutils \
      ftp \
      gcc \
      gettext-base \
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
      python3-crcmod \
      python3-dev \
      python3-pip \
      python3-setuptools \
      python3-venv \
      ssh \
      sudo \
      tmux \
      unzip \
      vim \
      wget \
      yq

# aws cli v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && /bin/rm -rf awscliv2.zip ./aws

# Set up virtual environment in /opt/gen3_venv
RUN python3 -m venv /opt/gen3_venv && \
    /opt/gen3_venv/bin/pip install --upgrade pip && \
    /opt/gen3_venv/bin/pip install "gen3>4" pyyaml && \
    chown -R ubuntu: /opt/gen3_venv

RUN echo 'export PATH="/opt/gen3_venv/bin:$PATH"' > /etc/profile.d/gen3.sh && \
    chmod +x /etc/profile.d/gen3.sh

# Set default shell path
ENV PATH="/opt/gen3_venv/bin:$PATH"

# From  https://hub.docker.com/r/google/cloud-sdk/~/dockerfile/
RUN export CLOUD_SDK_REPO="cloud-sdk" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y kubectl && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    kubectl version --client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/*

# Install postgres 13 client
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc| gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y postgresql-client-13

# install terraform
RUN curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.15/terraform_0.11.15_linux_amd64.zip \
   && unzip /tmp/terraform.zip -d /usr/local/bin && /bin/rm /tmp/terraform.zip

# Install Helm CLI
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

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

CMD ["/bin/bash"]
