# ooRexx XMPP-over-BOSH Adapter v0.1-dev2

This package implements the **XEP-0206 binding** between the Messaging & Presence XMPP session engine and the generic BOSH logical-stream package.

It exists separately so that:

- Messaging & Presence has no BOSH dependency;
- BOSH has no XMPP dependency;
- lower HTTP/HTTPS/socket/XTP selectors remain below BOSH;
- XMPP applications and intentions never choose or mention BOSH.

The adapter projects initial XMPP stream establishment into XEP-0206 BOSH attributes, maps post-SASL stream restart to `xmpp:restart='true'`, suppresses literal `<stream:stream>` payloads, carries normal XMPP stanzas unchanged as BOSH payload, and maps XMPP close onto BOSH termination.

Transport protection is **explicitly projected from the lower HTTP/transport authority**. The adapter does not infer security from an endpoint URI and it does not tunnel RFC 6120 STARTTLS inside BOSH. If the carrier is not already protected, the existing XMPP session engine fails closed before sending SASL credentials.

## dev2 observation boundary

The adapter is re-based on BOSH dev5. It does not manufacture Instrumentation correlation or causation identifiers. If a higher semantic authority chooses to correlate an XMPP operation with lower BOSH observations, that explicit context is supplied to the BOSH observation adapter outside this XEP-0206 transport mapping. XEP-0206 remains free of Instrumentation Mesh dependencies.
