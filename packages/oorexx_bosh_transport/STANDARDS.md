# Standards boundary

- XEP-0124: Bidirectional-streams Over Synchronous HTTP (BOSH) — generic BOSH transport semantics.
- XEP-0206 is intentionally **not implemented here**. XMPP-over-BOSH is an upper binding and is delivered as a separate package.

The dev4 extension-attribute seam is protocol-neutral: it carries upper-binding XML attributes without interpreting them and protects BOSH-owned attributes from replacement.
