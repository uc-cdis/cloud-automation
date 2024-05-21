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

# Install jq 1.6
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x jq-linux64 && mv jq-linux64 /usr/bin/jq

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get update && apt-get install -y nodejs

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

