#!/bin/bash
CFLAGS="-Os"
CXXFLAGS="-Os"
../squid-3.5.26/configure \
--prefix=/usr \
--exec-prefix=/usr \
--sysconfdir=/etc/squid \
--sharedstatedir=/var/lib \
--localstatedir=/var \
--datadir=/usr/share/squid \
--with-logdir=/var/log/squid \
--with-pidfile=/var/run/squid.pid \
--with-default-user=proxy \
--enable-linux-netfilter \
--with-openssl \
--without-nettle

make -j4
