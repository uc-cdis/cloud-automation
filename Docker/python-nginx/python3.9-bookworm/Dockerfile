# https://github.com/tiangolo/uwsgi-nginx-docker/blob/master/docker-images/python3.9.dockerfile
FROM quay.io/cdis/python:3.9-bookworm

ENV NGINX_VERSION   1.27.0
ENV NJS_VERSION     0.8.4
ENV NJS_RELEASE     2~bookworm
ENV PKG_RELEASE     2~bookworm

RUN set -x \
    # create nginx user/group first, to be consistent throughout docker variants
    && groupadd --system --gid 102 nginx \
    && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates nginx
    # && \
    # NGINX_GPGKEYS="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 8540A6F18833A80E9C1653A42FD21310B49F6B46 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3"; \
    # NGINX_GPGKEY_PATH=/etc/apt/keyrings/nginx-archive-keyring.gpg; \
    # export GNUPGHOME="$(mktemp -d)"; \
    # found=''; \
    # for NGINX_GPGKEY in $NGINX_GPGKEYS; do \
    # for server in \
    # hkp://keyserver.ubuntu.com:80 \
    # pgp.mit.edu \
    # ; do \
    # echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    # gpg1 --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    # done; \
    # test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    # done; \
    # gpg1 --export "$NGINX_GPGKEYS" > "$NGINX_GPGKEY_PATH" ; \
    # rm -rf "$GNUPGHOME"; \
    # apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    # && dpkgArch="$(dpkg --print-architecture)" \
    # && nginxPackages=" \
    # nginx=${NGINX_VERSION}-${PKG_RELEASE} \
    # nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
    # nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
    # nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
    # nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${NJS_RELEASE} \
    # " 
    # # \
    # && case "$dpkgArch" in \
    # amd64|arm64) \
    # # arches officialy built by upstream
    # echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/mainline/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list \
    # && apt-get update \
    # ;; \
    # *) \
    # # we're on an architecture upstream doesn't officially build for
    # # let's build binaries from the published source packages
    # echo "deb-src [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/mainline/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list \
    # \
    # # new directory for storing sources and .deb files
    # && tempDir="$(mktemp -d)" \
    # && chmod 777 "$tempDir" \
    # # (777 to ensure APT's "_apt" user can access it too)
    # \
    # # save list of currently-installed packages so build dependencies can be cleanly removed later
    # && savedAptMark="$(apt-mark showmanual)" \
    # \
    # # build .deb files from upstream's source packages (which are verified by apt-get)
    # && apt-get update \
    # && apt-get build-dep -y $nginxPackages \
    # && ( \
    # cd "$tempDir" \
    # && DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
    # apt-get source --compile $nginxPackages \
    # ) \
    # # we don't remove APT lists here because they get re-downloaded and removed later
    # \
    # # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    # # (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
    # && apt-mark showmanual | xargs apt-mark auto > /dev/null \
    # && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
    # \
    # # create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
    # && ls -lAFh "$tempDir" \
    # && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
    # && grep '^Package: ' "$tempDir/Packages" \
    # && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
    # # work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
    # #   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
    # #   ...
    # #   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
    # && apt-get -o Acquire::GzipIndexes=false update \
    # ;; \
    # esac \
    # \
    # && apt-get install --no-install-recommends --no-install-suggests -y \
    # $nginxPackages \
    # gettext-base \
    # curl 
    # # \
    # # && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    # # \
    # # # if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    # # && if [ -n "$tempDir" ]; then \
    # # apt-get purge -y --auto-remove \
    # # && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    # # fi \
    # # # forward request and error logs to docker log collector
    # # && ln -sf /dev/stdout /var/log/nginx/access.log \
    # # && ln -sf /dev/stderr /var/log/nginx/error.log \
    # # # create a docker-entrypoint.d directory
    # # && mkdir /docker-entrypoint.d


EXPOSE 80

# # Expose 443, in case of LTS / HTTPS
EXPOSE 443

# install uwsgi
# https://uwsgi-docs.readthedocs.io/en/latest/Install.html
RUN python -m pip install --upgrade pip
RUN pip install uwsgi ddtrace

# Remove default configuration from Nginx
# RUN rm /etc/nginx/conf.d/default.conf
# Copy the base uWSGI ini file to enable default dynamic uwsgi process number
COPY uwsgi.ini /etc/uwsgi/

COPY uwsgi.conf /etc/nginx/sites-available/

RUN ln -s /etc/nginx/sites-available/uwsgi.conf /etc/nginx/conf.d/uwsgi.conf

# Install Supervisord
RUN apt-get update && apt-get install -y supervisor \
    && rm -rf /var/lib/apt/lists/*
# Custom Supervisord config
COPY supervisord.ini /etc/supervisor.d/supervisord.ini

# Which uWSGI .ini file should be used, to make it customizable
ENV UWSGI_INI /app/uwsgi.ini

# By default, disable uwsgi cheaper mode and run 2 processes.
# If UWSGI_CHEAPER=N and UWSGI_PROCESSES=M, N is the min and M is the max
# number of processes. UWSGI_CHEAPER must be lower than UWSGI_PROCESSES.
# We set them here instead of in uwsgi.ini so that they can be overwritten.
ENV UWSGI_CHEAPER=
ENV UWSGI_PROCESSES=2

# By default, allow unlimited file sizes, modify it to limit the file sizes
# To have a maximum of 1 MB (Nginx's default) change the line to:
# ENV NGINX_MAX_UPLOAD 1m
ENV NGINX_MAX_UPLOAD 0

# By default, Nginx will run a single worker process, setting it to auto
# will create a worker for each CPU core
ENV NGINX_WORKER_PROCESSES 1

# By default, Nginx listens on port 80.
# To modify this, change LISTEN_PORT environment variable.
# (in a Dockerfile or with an option for `docker run`)
ENV LISTEN_PORT 80

# Copy the entrypoint that will generate Nginx additional configs
COPY entrypoint.sh /entrypoint.sh
COPY logrotate-nginx.conf /etc/logrotate.d/nginx
RUN chmod +x /entrypoint.sh

ENV PATH="/root/.cargo/bin:${PATH}"

COPY dockerrun.sh /dockerrun.sh
RUN mkdir -p /var/www/metrics/ && chmod +x /dockerrun.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]

# Add demo app
COPY ./app /app
WORKDIR /app

CMD ["/usr/bin/supervisord"]