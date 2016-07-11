FROM phusion/baseimage:latest
MAINTAINER Mark Stillwell <mark@stillwell.me>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -y install \
        ca-certificates \
        debconf \
        ldap-utils \
        ldapscripts \
        slapd \
        ssl-cert \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN useradd -G ssl-cert -d /var/lib/ldap -s /bin/false openldapd

COPY service.sh /etc/service/slapd/run

# data volumes
VOLUME [ "/var/lib/ldap", "/var/log" ]

# interface ports
EXPOSE 683
