# Odoo CRM Provider dev11 source catch-up

The unpacked tree under `packages/oorexx_odoo_crm_provider/` is still the previously published dev7.1-era source. It must **not** be described as dev11 until the exact delta below has been applied and the resulting tree is byte-verified.

- dev11 release archive SHA-256: `d27ecf896b551e1923e52be20d990423c6f79cc7093e61ab96e6c5a50d714479`
- dev7.1 -> dev11 unified patch SHA-256: `c0e9676053229dfddfee93985f824b48b5e2c304f9a1ef78ae72c64fd7d2d6af`
- stored gzip patch SHA-256: `f009483668ea36c68a7e9fd877e97b9ee6870909ae2dedf89dafad92e26b3f9c`

Stored at `releases/dev7.1_to_dev11.patch.gz`.

Verify before promotion:

```sh
sha256sum packages/oorexx_odoo_crm_provider/releases/dev7.1_to_dev11.patch.gz
gunzip -c packages/oorexx_odoo_crm_provider/releases/dev7.1_to_dev11.patch.gz | sha256sum
gunzip -c packages/oorexx_odoo_crm_provider/releases/dev7.1_to_dev11.patch.gz | git apply --check -
```

dev10 is the last provider baseline executed under ooRexx 5.3.0 r13196. dev11 adds the Relationship CRM Service adapter but its optional service integration regression still needs an r13196 run. Hosted Odoo remains proven through API Client 0.4.1 + Foreign Runtime 0.22.6 with verified TLS and HTTP1_ONLY. SIP dev13 still does not qualify originating INVITE/UAC.

See `spheres/relationship_crm_odoo_gopher_sphere_v0.1` for the authoritative architecture and continuation record.
