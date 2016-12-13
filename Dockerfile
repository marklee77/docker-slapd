FROM phusion/baseimage:latest
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

RUN usermod -a -G ssl-cert openldap
RUN rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
RUN rm -f /etc/ldap/ldap.conf
RUN mkdir -p /etc/ldap/dbinit.d

COPY slapd-setup.sh /etc/my_init.d/00-slapd-setup
COPY slapd-run.sh /etc/service/slapd/run
RUN chmod 755 /etc/my_init.d/00-slapd-setup /etc/service/slapd/run

VOLUME [ "/etc/ldap/slapd.d", "/var/lib/ldap" ]

EXPOSE 389 636
