# python2.7 microservice base image

FROM alpine:3.16.9

ENV DEBIAN_FRONTEND=noninteractive

RUN apk update && apk add --no-cache \
    python \ 
    py-pip \ 
    linux-headers \
    build-base \
    curl \
    git \
    bash \ 
    # dependency for cryptography
    libffi-dev \
    # dependency for pyscopg2 - which is dependency for sqlalchemy postgres engine
    postgresql-dev \
    # dependency for cryptography - commented out because it's debian-specific
    # openssl-dev \
    libxml2-dev \
    libxslt-dev \
    nginx \
    python-dev \
    sudo \
    vim \ 
    uwsgi-python

COPY nginx.conf /etc/nginx/
COPY uwsgi.conf /etc/nginx/sites-available/
COPY dockerrun.sh /dockerrun.sh

RUN adduser -S www-data -G www-data \ 
    && mkdir -p /var/www/.cache/Python-Eggs/ \
    && chown www-data -R /var/www/.cache/Python-Eggs/ \
    && mkdir /run/nginx/ \ 
    && mkdir -m 075 /var/run/gen3 \
    && chown root:www-data /dockerrun.sh \
    && chmod +x /dockerrun.sh \ 
    && chown root:www-data /var/run/gen3 \ 
    && chown -R www-data:www-data /var/tmp/nginx \
    && rm /etc/nginx/conf.d/default.conf \
    && ln -s /etc/nginx/sites-available/uwsgi.conf /etc/nginx/conf.d/uwsgi.conf \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

CMD [ "sh" ]
