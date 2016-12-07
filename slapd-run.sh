#!/bin/bash

: ${slapd_services:=ldapi:/// ldap:///}
: ${slapd_debuglevel:=0}

exec /usr/sbin/slapd -d $slapd_debuglevel -h "$slapd_services" -g openldap -u openldap -F /etc/ldap/slapd.d
