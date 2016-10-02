#!/bin/bash

: ${slapd_domain:=localdomain}
: ${slapd_admin_password:=password}
: ${slapd_services:=ldapi:/// ldap:///}
: ${slapd_base_dn:=dc=localdomain}
: ${slapd_enable_ssl:=yes}
: ${slapd_require_ssl:=yes}
: ${slapd_ssl_hostname:=localhost}
: ${slapd_ssl_cipher_suite:=SECURE256:!AES-128-CBC:!ARCFOUR-128:!CAMELLIA-128-CBC:!3DES-CBC:!CAMELLIA-128-CBC}
: ${slapd_ssl_cert_file:=/etc/ssl/certs/ssl-cert-snakeoil.pem}
: ${slapd_ssl_key_file:=/etc/ssl/private/ssl-cert-snakeoil.key}
: ${slapd_ssl_ca_cert_file:=/etc/ssl/certs/ca-certificates.crt}

umask 0022

if [ "$slapd_enable_ssl" = "yes" ] && [ -n "$slapd_ssl_cert_file "] && \
    ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$slapd_ssl_hostname" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
    update-ca-certificates
fi

debconf-set-selections <<EOF
slapd slapd/domain string $slapd_domain
slapd slapd/password1 password $slapd_admin_password
slapd slapd/password2 password $slapd_admin_password
EOF

echo "$slapd_admin_password" > /etc/ldapscripts/ldapscripts.passwd
chmod 0640 /etc/ldapscripts/ldapscripts.passwd

dpkg-reconfigure -f noninteractive slapd

cat > /etc/ldap/slapd.conf <<EOF
TLSCACertificateFile $slapd_ssl_ca_cert_file
TLSCertificateKeyFile $slapd_ssl_cert_file
TLSCertificateFile $slapd_ssl_key_file
EOF

exec /usr/sbin/slapd -d0 -h "${slapd_services}" -g openldap -u openldap -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
