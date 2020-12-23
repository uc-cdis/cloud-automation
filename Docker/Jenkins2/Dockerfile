FROM jenkins/jenkins:2.233

USER root

ENV DEBIAN_FRONTEND=noninteractive

# install python and pip and aws cli
RUN set -xe && apt-get update && apt-get install -y apt-utils dnsutils python python-setuptools python-dev python-pip python3 python3-pip build-essential zip unzip jq less vim gettext-base
RUN set -xe && python -m pip install awscli --upgrade && python -m pip install pytest --upgrade && python -m pip install PyYAML --upgrade
RUN set -xe && python3 -m pip install pytest --upgrade && python3 -m pip install PyYAML --upgrade
RUN set -xe && python -m pip install yq --upgrade && python3 -m pip install yq --upgrade

# add our custom start script
COPY jenkins2.sh /opt/cdis/bin/jenkins2.sh
RUN chmod -R a+rx /opt/cdis
ENTRYPOINT ["/sbin/tini", "--", "/opt/cdis/bin/jenkins2.sh"]

USER jenkins
