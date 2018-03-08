# To run: docker run -d -v /path/to/local_settings.py:/var/www/fence/local_settings.py --name=fence -p 80:80 fence
# To check running container: docker exec -it fence /bin/bash

FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    python2.7 \
    python-dev \
    python-pip \
    python-setuptools \
    vim \
    less \
    jq \
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod a+rx kubectl \
    && mv kubectl /usr/local/bin/ \
    && pip install --upgrade pip \
    && pip install --upgrade setuptools \
    && pip install awscli --upgrade \
    && pip install yq --upgrade

RUN useradd -m -s /bin/bash ubuntu

WORKDIR /home/ubuntu
USER ubuntu

CMD /bin/bash
