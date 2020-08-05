#!/bin/bash
set -e

create_log_dir() {
    mkdir -p ${SQUID_LOG_DIR}
    chmod -R 755 ${SQUID_LOG_DIR}
    chown -R ${SQUID_USER}:${SQUID_USER} ${SQUID_LOG_DIR}
}

create_cache_dir() {
    mkdir -p ${SQUID_CACHE_DIR}
    chown -R ${SQUID_USER}:${SQUID_USER} ${SQUID_CACHE_DIR}
}

apply_backward_compatibility_fixes() {
    if [[ -f ${SQUID_SYSCONFIG_DIR}/squid.user.conf ]]; then
        rm -rf ${SQUID_SYSCONFIG_DIR}/squid.conf
        ln -sf ${SQUID_SYSCONFIG_DIR}/squid.user.conf ${SQUID_SYSCONFIG_DIR}/squid.conf
    fi
}

create_log_dir
create_cache_dir
apply_backward_compatibility_fixes

# allow arguments to be passed to squid
if [[ ${1:0:1} = '-' ]]; then
    EXTRA_ARGS="$@"
    set --
elif [[ ${1} == squid || ${1} == $(which squid) ]]; then
    EXTRA_ARGS="${@:2}"
    set --
fi

# default behaviour is to launch squid
if [[ -z ${1} ]]; then
    if [[ ! -d ${SQUID_CACHE_DIR}/00 ]]; then
        echo "Initializing cache..."
        $(which squid) -N -f ${SQUID_SYSCONFIG_DIR}/squid.conf -z
    fi
    echo "Starting squid..."
    exec $(which squid) -f ${SQUID_SYSCONFIG_DIR}/squid.conf -NYCd 1 ${EXTRA_ARGS}
else
    exec "$@"
fi
