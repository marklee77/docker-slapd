#!/bin/bash

: ${slapd_domain:=localdomain}
: ${slapd_admin_password:=} # FIXME: generate
: ${slapd_admin_password_salt:=} # FIXME: generate
: ${slapd_services:=ldap:/// ldapi:///}
: ${slapd_base_dn:=dc=localdomain}
: ${slapd_enable_ssl:=yes}
: ${slapd_require_ssl:=yes}
: ${slapd_ssl_hostname:=localhost}
: ${slapd_ssl_cipher_suite:=SECURE256:!AES-128-CBC:!ARCFOUR-128:!CAMELLIA-128-CBC:!3DES-CBC:!CAMELLIA-128-CBC}
: ${slapd_ssl_cert_file:=/etc/ssl/certs/ssl-cert-snakeoil.pem}
: ${slapd_ssl_key_file:=/etc/ssl/private/ssl-cert-snakeoil.key}
: ${slapd_ssl_ca_cert_fil:=/etc/ssl/certs/ca-certificates.crt}

echo "slapd slapd/domain string $slapd_domain" | debconf-set-selections
dpkg-reconfigure -f noninteractive slapd

if [ "$slapd_enable_ssl" = "yes" ] && [ -n "$slapd_ssl_cert_file "] && \
    ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$slapd_ssl_hostname" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
    update-ca-certificates
fi

exec /usr/sbin/slapd -h "${slapd_services}" -g openldap -u openldap -F /etc/ldap/slapd.d

# FIXME: use my_init.d for below:
# - set root password
# - configure ssl or not
# - require ssl if needed
# - allow bind
# - enable membership overlay and configure
# - enable refint overlay and configure
# - enable unique overlay and configure
# - setup indexes
# - ldapscripts

