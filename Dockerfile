FROM marklee77/supervisor:xenial
MAINTAINER Mark Stillwell <mark@stillwell.me>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        ca-certificates \
        ldap-utils \
        pwgen \
        slapd \
        ssl-cert && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p /etc/ssl/container

RUN usermod -a -G ssl-cert openldap
RUN rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
RUN rm -f /etc/ldap/ldap.conf
RUN mkdir -p /etc/ldap/dbinit.d

COPY root/etc/my_init.d/10-slapd-setup /etc/my_init.d/
COPY root/usr/local/sbin/slapd-run /usr/local/sbin/
RUN chmod 755 /etc/my_init.d/10-slapd-setup /usr/local/sbin/slapd-run

COPY root/etc/supervisor/conf.d/slapd.conf /etc/supervisor/conf.d/
RUN chmod 644 /etc/supervisor/conf.d/slapd.conf

VOLUME [ "/etc/ldap/slapd.d", "/etc/ssl/container", "/var/lib/ldap" ]

EXPOSE 389 636
