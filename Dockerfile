FROM marklee77/supervisor:jessie
MAINTAINER Mark Stillwell <mark@stillwell.me>

ENV DEBIAN_FRONTEND noninteractive
RUN groupadd -g 200 openldap && \
    useradd -u 200 -g 200 -r openldap && \
    apt-get update && \
    apt-get -y install --no-install-recommends \
        ca-certificates \
        ldap-utils \
        pwgen \
        slapd && \
    rm -rf \
        /etc/ldap/ldap.conf \
        /etc/ldap/slapd.d \
        /var/cache/apt/* \
        /var/lib/apt/lists/* \
        /var/lib/ldap

RUN mkdir -m 0755 -p /etc/ssl/slapd && \
    ln -s /data/ssl/ca.crt /etc/ssl/slapd/ca.crt && \
    ln -s /data/ssl/ldap.crt /etc/ssl/slapd/ldap.crt && \
    ln -s /data/ssl/ldap.key /etc/ssl/slapd/ldap.key

RUN ln -s /data/slapd/ldap.conf /etc/ldap/ldap.conf && \
    ln -s /data/slapd/ldap.passwd /etc/ldap/ldap.passwd && \
    ln -s /data/slapd/config.d /etc/ldap/slapd.d && \
    ln -s /data/slapd/db /var/lib/ldap

COPY root/etc/my_init.d/10-slapd-setup /etc/my_init.d/
COPY root/usr/local/sbin/slapd-run /usr/local/sbin/
RUN chmod 0755 /etc/my_init.d/10-slapd-setup /usr/local/sbin/slapd-run
RUN mkdir -m 0755 -p /etc/ldap/dbinit.d

COPY root/etc/supervisor/conf.d/slapd.conf /etc/supervisor/conf.d/
RUN chmod 644 /etc/supervisor/conf.d/slapd.conf

EXPOSE 389 636
