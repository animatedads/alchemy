from pathlib import Path
root=Path(__file__).resolve().parents[1]
sip=(root/"src/sip.cls").read_text()
adapter=(root/"src/sip_ldap_identity.cls").read_text()
assert "::class SipCredentialProvider public" in sip
assert "::class SipDigestAuthorization public" in sip
assert "credentialProvider=.nil" in sip
assert "SIP.AUTH.CREDENTIAL.PROVISION" in sip
assert "!DENY!" in sip
assert "::class SipLdapIdentityCredentialProvider subclass SipCredentialProvider public" in adapter
assert "SIP_DIGEST_SECRET" in adapter
assert "broker~acquire" in adapter
assert "secretForTrustedConsumer" in adapter
assert "lease~retire" in adapter
assert "server~credential" in adapter
print("PASS SIP LDAP credential provider source contract")