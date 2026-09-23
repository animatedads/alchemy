#!/bin/sh
set -eu
: "${REXX:=rexx}"
"$REXX" tests/test_core.rex
"$REXX" tests/test_chapter9.rex
"$REXX" tests/test_profile.rex
"$REXX" tests/test_configuration_state.rex
"$REXX" tests/test_fido_hid_profile.rex
"$REXX" tests/test_fido_ctaphid.rex
"$REXX" tests/test_fido_getinfo.rex
"$REXX" tests/test_fido_credentials.rex
"$REXX" tests/test_raw_gadget_bridge.rex
"$REXX" examples/virtual_crypto_profile.rex
"$REXX" examples/virtual_fido2_authenticator.rex
