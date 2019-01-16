# python2.7 microservice base image

FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    # dependency for cryptography
    libffi-dev \
    # dependency for pyscopg2 - which is dependency for sqlalchemy postgres engine
    libpq-dev \
    # dependency for cryptography
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    nginx \
    python2.7 \
    python-dev \
    python-pip \
    python-setuptools \
    sudo \
    vim \
    && python -m pip install --upgrade pip \
    && python -m pip install --upgrade setuptools \
    && python -m pip install uwsgi 