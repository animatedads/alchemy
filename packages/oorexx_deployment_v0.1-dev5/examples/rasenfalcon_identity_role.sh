#!/bin/sh
# Example only: build a reviewable identity role. This does not install/start it.
set -eu
DEPLOYMENT_HOME=${DEPLOYMENT_HOME:?set DEPLOYMENT_HOME to oorexx_deployment_v0.1-dev5}
LDAP_ROOT=${LDAP_ROOT:?set LDAP_ROOT to verified oorexx_ldap_identity_v0.1-dev22 extraction}
LDAP_NAMESPACE=${LDAP_NAMESPACE:?set LDAP_NAMESPACE to verified sealed dependency namespace}
OUT=${OUT:-./release/roles/identity}
"$DEPLOYMENT_HOME/bin/build_rasenfalcon_identity_role.sh" \
  --ldap-root "$LDAP_ROOT" \
  --namespace "$LDAP_NAMESPACE" \
  --output "$OUT" \
  --ldap-archive-sha256 697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc \
  --ldap-source-commit 0495e8604c62fc780aff3c95b94c935415ffc57d
