# python2.7 microservice base image

FROM python:2.7-alpine3.7

ENV DEBIAN_FRONTEND=noninteractive

RUN apk update && apk add --no-cache \
    build-base \
    curl \
    git \
    # dependency for cryptography
    libffi-dev \
    # dependency for pyscopg2 - which is dependency for sqlalchemy postgres engine
    postgresql-dev \
    # dependency for cryptography
    # openssl-dev \
    libxml2-dev \
    libxslt-dev \
    nginx \
    python-dev \
    sudo \
    vim \ 
    uwsgi-python

RUN adduser -S www-data -G www-data

CMD [ "sh" ]