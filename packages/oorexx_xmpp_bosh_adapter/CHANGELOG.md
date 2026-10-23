# Changelog

## 0.1-dev2

- Rebased the XEP-0206 binding on generic BOSH transport v0.1-dev5.
- Documented the Instrumentation Mesh dev8 boundary: the XEP-0206 adapter never fabricates correlation, causation or external context.
- Retained the existing XMPP/BOSH stream, SASL, restart, bind, close and fail-closed security semantics unchanged.
- No application- or intention-visible BOSH surface was introduced.

# CHANGELOG

## 0.1-dev1

- Initial XEP-0206 adapter package.
- Initial BOSH body carries `xmlns:xmpp='urn:xmpp:xbosh'` and `xmpp:version='1.0'`.
- Literal XMPP stream-open tags are projected rather than sent as BOSH payload.
- Post-SASL stream restart maps to `xmpp:restart='true'`.
- Normal XMPP stanzas remain payload.
- XMPP stream close maps to BOSH termination.
- Lower transport protection is an explicit injected fact; unprotected carriers fail closed before SASL.
