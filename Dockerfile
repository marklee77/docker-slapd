FROM phusion/baseimage:latest
MAINTAINER Mark Stillwell <mark@stillwell.me>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -y install \
        ca-certificates \
        ldap-utils \
        slapd \
        ssl-cert && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN usermod -a -G ssl-cert openldap
RUN rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
RUN rm -f /etc/ldap/ldap.conf

COPY slapd.sh /etc/service/slapd/run

VOLUME [ "/etc/ldap", "/etc/ssl", "/usr/local/share/ca-certificates", \
         "/var/lib/ldap", "/var/log", "/var/run/ldap" ]

EXPOSE 389 636
