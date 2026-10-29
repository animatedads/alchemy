# SIP dev17 — LDAP Identity credential provisioning

SIP Digest authentication remains SIP protocol authority, but credential identity and secret ownership can now be supplied by the platform Identity Directory.

`SipServer` accepts an optional `SipCredentialProvider`. On an authenticated request it extracts the Digest username and asks the provider to provision the native Digest engine immediately before verification. Provider failure is fail-closed: the username is overwritten with a one-use invalid sentinel before native verification, so an earlier cached secret cannot survive account revocation or provider failure.

`SipLdapIdentityCredentialProvider` is optional and does not make LDAP a media/call dependency. It:

1. resolves an ACTIVE Identity Directory principal by login name/entity id;
2. selects an ACTIVE, currently valid `SIP_DIGEST_SECRET` credential record;
3. acquires the credential's `secretRef` through Secret Broker;
4. materializes the secret only inside the trusted provisioning method;
5. calls `SipServer~credential()`;
6. retires the Secret Broker lease before returning.

No raw secret is placed in Alchemy Log or Instrumentation Mesh. Calls, RTP, AudioIn, AudioOut, STT and TTS remain independent of Identity Directory lifecycle.

This increment consumes LDAP Identity v0.1-dev22 semantics; it does not edit LDAP Identity.