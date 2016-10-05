#!/bin/bash

: ${slapd_domain:=localdomain}
: ${slapd_base_dn:=dc=$(echo $slapd_domain | sed 's/^\.//; s/\./,dc=/g')}
: ${slapd_admin_password:=password}

: ${slapd_enable_ssl:=yes}
: ${slapd_require_ssl:=yes}
: ${slapd_ssl_hostname:=localhost}
: ${slapd_ssl_ca_cert_file:=/etc/ssl/certs/ca-certificates.crt}
: ${slapd_ssl_cipher_suite:=SECURE256:!AES-128-CBC:!ARCFOUR-128:!CAMELLIA-128-CBC:!3DES-CBC:!CAMELLIA-128-CBC}
: ${slapd_ssl_cert_file:=/etc/ssl/certs/ssl-cert-snakeoil.pem}
: ${slapd_ssl_key_file:=/etc/ssl/private/ssl-cert-snakeoil.key}

: ${slapd_services:=ldapi:/// ldap:///}
: ${slapd_debuglevel:=0}

umask 0022

if [ "$slapd_enable_ssl" = "yes" ] && [ -n "$slapd_ssl_cert_file" ] && \
    ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$slapd_ssl_hostname" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
    update-ca-certificates
fi

if [ ! -f "/etc/ldap/slapd.d/cn=config.ldif" ]; then
  slapd_admin_password_hash=$(slappasswd -s "$slapd_admin_password")
  cat /usr/share/slapd/slapd.init.ldif | \
      sed "s|@BACKEND@|mdb|g" | \
      sed "s|@BACKENDOBJECTCLASS@|olcMdbConfig|g" | \
      sed "s|@BACKENDOPTIONS@|olcDbMaxSize: 1073741824|g" | \
      sed "s|@SUFFIX@|$slapd_base_dn|g" | \
      sed "s|@PASSWORD@|$slapd_admin_password_hash|g" | \
      slapadd -b cn=config -F /etc/ldap/slapd.d
  chown -R openldap:openldap /etc/ldap/slapd.d
fi

if [ ! -f /etc/ldapscripts/ldapscripts.passwd ]; then
  echo "$slapd_admin_password" > /etc/ldapscripts/ldapscripts.passwd
  chmod 0640 /etc/ldapscripts/ldapscripts.passwd
fi

exec /usr/sbin/slapd -d $slapd_debuglevel -h "${slapd_services}" -g openldap -u openldap -F /etc/ldap/slapd.d
