marklee77/slapd
===============

This docker image configures and launches slapd.

Parameters and default values:

- slapd_domain (localdomain)
- slapd_basedn (based on slapd_domain)
- slapd_admin_password (random)
- slapd_enable_ssl (yes)
- slapd_require_ssl (yes)
- slapd_ssl_hostname (slapd_domain)
- slapd_ssl_ca_cert_file (/etc/ssl/certs/ca-certificates.crt)
- slapd_ssl_cert_file (/usr/local/share/ca-certificates/slapd.crt)
- slapd_ssl_key_file (/etc/ssl/private/slapd.key -- generated and self-signed if not present)
- slapd_disable_anon (yes)
- slapd_services (ldapi:/// ldap:///)
- slapd_debuglevel (0)

author
======

Mark Stillwell <mark@stillwell.me>
