FROM jenkins/jenkins:2.426.3-lts-jdk21

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils build-essential zip unzip jq less vim gettext-base wget

RUN set -xe && apt-get update \
  && apt-get install -y lsb-release \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     libffi-dev \
     libssl-dev \
     libcurl4-openssl-dev \
     libncurses5-dev \
     libncursesw5-dev \
     libreadline-dev \
     libsqlite3-dev \
     libgdbm-dev \
     libdb5.3-dev \
     libbz2-dev \
     libexpat1-dev \
     liblzma-dev \
     lua5.3 \
     r-base \
     software-properties-common \
     sudo \
     tk-dev \
     wget \
     zlib1g-dev \
     zsh \
  && ln -s /usr/bin/lua5.3 /usr/local/bin/lua

# update /etc/sudoers
RUN sed 's/^%sudo/#%sudo/' /etc/sudoers > /etc/sudoers.bak \
  && /bin/echo -e "\n%sudo    ALL=(ALL:ALL) NOPASSWD:ALL\n" >> /etc/sudoers.bak \
  && cp /etc/sudoers.bak /etc/sudoers \
  && usermod -G sudo jenkins

# add our custom start script
COPY jenkins.sh /opt/cdis/bin/jenkins.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/cdis/bin/jenkins.sh"]

USER jenkins

RUN git config --global user.email jenkins \
    && git config --global user.name jenkins
