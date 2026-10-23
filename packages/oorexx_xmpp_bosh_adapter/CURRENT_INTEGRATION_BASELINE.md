# Current integration baseline checked 2026-10-15

This XEP-0206 adapter is qualified structurally against generic BOSH v0.1-dev5 and Messaging & Presence v0.1-dev4.

The current Library transport grid records Socket Provider v0.1-dev16 and XTP v0.1-dev19 beneath the generic selector/provider boundary. Neither is a dependency of this adapter. HTTPS-over-XTP remains a legal lower composition without XEP-0206 knowing that XTP exists.
