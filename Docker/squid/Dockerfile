FROM quay.io/cdis/ubuntu:18.04

ENV SQUID_VERSION="squid-5.1" \
    SQUID_DOWNLOAD_URL="http://www.squid-cache.org/Versions/v5/" \  
    SQUID_USER="proxy" \
    SQUID_CACHE_DIR="/var/cache/squid" \
    SQUID_LOG_DIR="/var/log/squid" \
    SQUID_SYSCONFIG_DIR="/etc/squid" \
    SQUID_PID_DIR="/var/run/squid" \
    CFLAGS="-Os" \
    CXXFLAGS="-Os"


RUN apt update \
    && apt install -y build-essential wget libssl1.0-dev

COPY ./entrypoint.sh /usr/sbin/entrypoint.sh
COPY ./certfix.sh /certfix.sh

RUN chmod +x /usr/sbin/entrypoint.sh
RUN chmod +x /certfix.sh
RUN bash /certfix.sh

RUN (cd /tmp \
    && wget ${SQUID_DOWNLOAD_URL}${SQUID_VERSION}.tar.xz \
    && tar -xJf ${SQUID_VERSION}.tar.xz \
    && sed -i 's/if (rawPid <= 1)/if (rawPid < 1)/' ${SQUID_VERSION}/src/Instance.cc \
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
    --with-pidfile=${SQUID_PID_DIR}/squid.pid \
    --with-default-user=${SQUID_USER} \
    --enable-linux-netfilter \
    --with-openssl \
    --without-nettle \
    --disable-arch-native \
    &&  make \
    && make install)

RUN (cd /tmp \
    && rm ${SQUID_VERSION}.tar.xz \
    && rm -rf ${SQUID_VERSION} squid-build)

COPY ./ERR_ACCESS_DENIED /usr/share/squid/errors/templates/ERR_ACCESS_DENIED
    
RUN mkdir -p ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR} \
    && chown -R ${SQUID_USER}. ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR}

EXPOSE 3128/tcp
EXPOSE 3129/tcp
EXPOSE 3130/tcp

VOLUME ${SQUID_LOG_DIR} ${SQUID_CACHE_DIR} ${SQUID_PID_DIR} ${SQUID_SYSCONFIG_DIR}

ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
