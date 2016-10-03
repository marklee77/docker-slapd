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

debconf-set-selections <<EOF
slapd slapd/domain string $slapd_domain
slapd slapd/password1 password $slapd_admin_password
slapd slapd/password2 password $slapd_admin_password
EOF
dpkg-reconfigure -f noninteractive slapd

if [ "$slapd_enable_ssl" = "yes" ] && [ -n "$slapd_ssl_cert_file "] && \
    ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$slapd_ssl_hostname" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
    update-ca-certificates
fi

/usr/sbin/slapd -h ldapi:/// -g openldap -u openldap -F /etc/ldap/slapd.d
while true; do
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $slapd_ssl_ca_cert_file
-
replace: olcTLSCipherSuite
olcTLSCipherSuite: $slapd_ssl_cipher_suite
-
replace: olcTLSCertificatefile
olcTLSCertificatefile: $slapd_ssl_cert_file
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $slapd_ssl_key_file
EOF
[ $? == 0 ] && break
sleep 5
done
while pkill slapd; do sleep 1; done

echo "$slapd_admin_password" > /etc/ldapscripts/ldapscripts.passwd
chmod 0640 /etc/ldapscripts/ldapscripts.passwd

exec /usr/sbin/slapd -d $slapd_debuglevel -h "${slapd_services}" -g openldap -u openldap -F /etc/ldap/slapd.d
