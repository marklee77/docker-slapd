#!/bin/bash

: ${slapd_domain:=localdomain}
: ${slapd_base_dn:=dc=$(echo $slapd_domain | sed 's/^\.//; s/\./,dc=/g')}
: ${slapd_organization:=$slapd_domain}
: ${slapd_admin_password:=$(pwgen -s1 32)}

: ${slapd_enable_ssl:=yes}
: ${slapd_ssl_hostname:=$slapd_domain}
: ${slapd_ssl_ca_cert_file:=/etc/ssl/certs/ca-certificates.crt}
: ${slapd_ssl_cert_file:=/usr/local/share/ca-certificates/slapd.crt}
: ${slapd_ssl_key_file:=/etc/ssl/private/slapd.key}

: ${slapd_require_ssl:=yes}

: ${slapd_disable_anon:=yes}

: ${slapd_services:=ldapi:/// ldap:///}
: ${slapd_debuglevel:=0}

umask 0022

echo "127.0.1.1\t$slapd_domain" >> /etc/hosts

if [ "$slapd_enable_ssl" = "yes" ] && ! [ -f "$slapd_ssl_cert_file" ]; then
    openssl req -newkey rsa:2048 -x509 -nodes -days 365 \
        -subj "/CN=$slapd_ssl_hostname" \
        -out $slapd_ssl_cert_file -keyout $slapd_ssl_key_file
fi

# in case user maps a ca cert into /usr/local/share/ca-certificates
update-ca-certificates

cat > /etc/ldap/ldap.conf <<EOF
URI ldapi:///
BASE $slapd_base_dn
TLS_CACERT $slapd_ssl_ca_cert_file
SASL_MECH EXTERNAL
EOF

echo -n "$slapd_admin_password" > /etc/ldapscripts/ldapscripts.passwd
chmod 0640 /etc/ldapscripts/ldapscripts.passwd

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

    # start slapd on local socket and wait for it to come up
    /usr/sbin/slapd -h ldapi:/// -g openldap -u openldap -F /etc/ldap/slapd.d
    while ! ldapsearch -b cn=config >/dev/null 2>&1; do
        sleep 1
    done

    [ "$slapd_enable_ssl" = yes ] && ldapmodify <<EOF
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

    # load desired modules
    ldapadd <<EOF
dn: cn=module,cn=config
cn: module
objectClass: olcModuleList
objectClass: top
olcModuleLoad: memberof.la
olcModulePath: /usr/lib/ldap

dn: olcOverlay=memberof,olcDatabase={1}mdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcMemberOf
objectClass: top
olcOverlay: memberof

dn: cn=module,cn=config
cn: module
objectClass: olcModuleList
objectClass: top
olcModuleLoad: refint.la
olcModulePath: /usr/lib/ldap

dn: olcOverlay=refint,olcDatabase={1}mdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: refint
olcRefintAttribute: memberof member manager owner

dn: cn=module,cn=config
cn: module
objectClass: olcModuleList
objectClass: top
olcModuleLoad: unique.la
olcModulePath: /usr/lib/ldap

dn: olcOverlay=unique,olcDatabase={1}mdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcUniqueConfig
objectClass: top
olcOverlay: unique
olcUniqueURI: ldap:///?uid,uidNumber,mail?sub
EOF

    # create organisation and organisational units
    ldapadd -D cn=admin,$slapd_base_dn -y /etc/ldapscripts/ldapscripts.passwd <<EOF
dn: $slapd_base_dn
objectClass: dcObject
objectClass: organization
o: $slapd_organization

dn: ou=users,$slapd_base_dn
objectClass: organizationalUnit
ou: users

dn: ou=groups,$slapd_base_dn
objectClass: organizationalUnit
ou: groups

dn: ou=services,$slapd_base_dn
objectClass: organizationalUnit
ou: services

dn: ou=machines,$slapd_base_dn
objectClass: organizationalUnit
ou: machines
EOF

    # make sure that slapd is not running
    while pkill -INT slapd; do sleep 1; done

fi

exec /usr/sbin/slapd -d $slapd_debuglevel -h "${slapd_services}" -g openldap -u openldap -F /etc/ldap/slapd.d
