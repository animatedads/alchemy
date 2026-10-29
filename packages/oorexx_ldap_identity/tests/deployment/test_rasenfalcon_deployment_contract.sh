#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BOOT="$ROOT/bin/rasenfalcon_ldap_service.rex"
UNIT="$ROOT/deployment/rasenfalcon/rasenfalcon-ldap.service"
ENVF="$ROOT/deployment/rasenfalcon/ldap.env.example"
MAP="$ROOT/deployment/rasenfalcon/ldap-secrets.map.example"

test -s "$BOOT"; test -s "$UNIT"; test -s "$ENVF"; test -s "$MAP"
grep -q 'User=rasenfalcon-ldap' "$UNIT"
grep -q 'NoNewPrivileges=true' "$UNIT"
grep -q 'ProtectSystem=strict' "$UNIT"
grep -q 'RF_LDAP_CERT_FILE' "$BOOT"
grep -q 'RF_LDAP_KEY_FILE' "$BOOT"
grep -q 'OpenSslLdapTlsProvider' "$BOOT"
grep -q 'resource:directory' "$BOOT"
grep -q 'MappedEnvironmentSecretProvider' "$BOOT"
! grep -Eq 'slapd|dovecot|postfix|nginx' "$BOOT" "$UNIT"
! grep -Eq 'password=|secret=[^#]' "$ENVF" "$MAP"

echo 'PASS Rasen Falcon LDAP deployment contract'
