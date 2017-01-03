#!/bin/bash

: ${slapd_basedn:=dc=ldap,dc=dit}
: ${slapd_admin_password:=$(pwgen -s1 32)}

: ${slapd_require_ssl:=yes}
: ${slapd_ssl_ca_cert_file:=/etc/ssl/container/slapd-ca.crt}
: ${slapd_ssl_cert_file:=/etc/ssl/container/slapd.crt}
: ${slapd_ssl_key_file:=/etc/ssl/container/slapd.key}

: ${slapd_disable_anon:=yes}

[ -f "/etc/ldap/slapd.d/cn=config.ldif" ] && exit 0

# set secure umask
umask 0227

if ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$(hostname)" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
    chmod 0444 $slapd_ssl_cert_file
    chgrp ssl-cert $slapd_ssl_key_file
fi

if ! [ -f "$slapd_ssl_ca_cert_file" ]; then
    ln -s $slapd_ssl_cert_file $slapd_ssl_ca_cert_file
fi

echo -n "$slapd_admin_password" > /etc/ldap/ldap.passwd

# set normal umask
umask 0022

cat > /etc/ldap/ldap.conf <<EOF
URI ldapi:///
BASE $slapd_basedn
TLS_CACERT $slapd_ssl_ca_cert_file
SASL_MECH EXTERNAL
EOF

cat /usr/share/slapd/slapd.init.ldif | \
    sed "s|@BACKEND@|mdb|g" | \
    sed "s|@BACKENDOBJECTCLASS@|olcMdbConfig|g" | \
    sed "s|@BACKENDOPTIONS@|olcDbMaxSize: 1073741824|g" | \
    sed "s|@SUFFIX@|$slapd_basedn|g" | \
    sed "s|@PASSWORD@|$(slappasswd -T /etc/ldap/ldap.passwd)|g" | \
    slapadd -b cn=config -F /etc/ldap/slapd.d
chown -R openldap:openldap /etc/ldap/slapd.d

# start slapd on local socket and wait for it to come up
/usr/sbin/slapd -h ldapi:/// -g openldap -u openldap -F /etc/ldap/slapd.d
while ! ldapsearch -b cn=config >/dev/null 2>&1; do sleep 1; done

ldapmodify <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCipherSuite
olcTLSCipherSuite: SECURE256:+SECURE128:-VERS-TLS-ALL:+VERS-TLS1.2:-RSA:-DHE-DSS:-CAMELLIA-128-CBC:-CAMELLIA-256-CBC
-
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $slapd_ssl_ca_cert_file
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: $slapd_ssl_cert_file
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $slapd_ssl_key_file
EOF

[ "$slapd_require_ssl" = yes ] && ldapmodify <<EOF
dn: cn=config
changetype: modify
replace: olcLocalSSF
olcLocalSSF: 128
-
replace: olcSecurity
olcSecurity: ssf=128
EOF

[ "$slapd_disable_anon" = yes ] && ldapmodify <<EOF
dn: cn=config
changetype: modify
replace: olcDisallows
olcDisallows: bind_anon
-
replace: olcRequires
olcRequires: authc
EOF

export slapd_basedn slapd_admin_password
for file in $(find -L /etc/ldap/dbinit.d -type f -executable | sort); do
    $file
done

# make sure that slapd is not running
pidfile=/var/run/slapd/slapd.pid
while [ -f $pidfile ] && kill -INT $(cat $pidfile); do sleep 1; done
