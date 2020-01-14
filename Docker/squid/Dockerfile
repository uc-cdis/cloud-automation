
FROM ubuntu:18.04

ENV SQUID_VERSION="squid-4.8" \
    SQUID_DOWNLOAD_URL="http://www.squid-cache.org/Versions/v4/" \
    SQUID_USER="proxy" \
    SQUID_CACHE_DIR="/var/cache/squid" \
    SQUID_LOG_DIR="/var/log/squid" \
    SQUID_SYSCONFIG_DIR="/etc/squid" \
    CFLAGS="-Os" \
    CXXFLAGS="-Os"


RUN apt update \
    && apt install -y build-essential wget libssl1.0-dev libcap2

COPY ./entrypoint.sh /usr/sbin/entrypoint.sh

RUN chmod +x /usr/sbin/entrypoint.sh

RUN (cd /tmp \
    && wget ${SQUID_DOWNLOAD_URL}${SQUID_VERSION}.tar.xz \
    && tar -xJf ${SQUID_VERSION}.tar.xz \
    && mkdir squid-build \
    && cd squid-build \
    && ../${SQUID_VERSION}/configure \
    --prefix=/usr \
    --exec-prefix=/usr \
    --sysconfdir=${SQUID_SYSCONFIG_DIR} \
    --sharedstatedir=/var/lib \
    --localstatedir=/var \
    --datadir=/usr/share/squid \
    --with-logdir=${SQUID_LOG_DIR} \
    --with-pidfile=/var/run/squid.pid \
    --with-default-user=${SQUID_USER} \
    --enable-linux-netfilter \
    --with-openssl \
    --without-nettle \
    &&  make \
    && make install)

RUN mkdir ${SQUID_SYSCONFIG_DIR}/ssl \
    && openssl genrsa -out ${SQUID_SYSCONFIG_DIR}/ssl/squid.key 2048 \
    && openssl req -new -key ${SQUID_SYSCONFIG_DIR}/ssl/squid.key -out ${SQUID_SYSCONFIG_DIR}/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid' \
    && openssl x509 -req -days 3650 -in ${SQUID_SYSCONFIG_DIR}/ssl/squid.csr -signkey ${SQUID_SYSCONFIG_DIR}/ssl/squid.key -out ${SQUID_SYSCONFIG_DIR}/ssl/squid.crt \
    && cat ${SQUID_SYSCONFIG_DIR}/ssl/squid.key ${SQUID_SYSCONFIG_DIR}/ssl/squid.crt | tee ${SQUID_SYSCONFIG_DIR}/ssl/squid.pem \
    && mkdir -p ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR} \
    && chown -R ${SQUID_USER}. ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR}

EXPOSE 3128/tcp

VOLUME ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR}

ENTRYPOINT ["/usr/sbin/entrypoint.sh"]


