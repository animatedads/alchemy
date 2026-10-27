# Relationship CRM ↔ Odoo — LLM Gopher sphere v0.1

This sphere documents the ooRexx integration between Relationship CRM, hosted Odoo JSON-2 and SIP caller/call evidence. It is deliberately separate from the Customer Service Agents audiovisual sphere: presentation/rendering and CRM/provider authority are different concerns.

Start with `arch.crm-odoo.authority`, then `arch.crm-odoo.live-object` and `arch.crm-odoo.service`. `qual.crm-odoo.current` records exactly what has and has not been executed, and `ops.crm-odoo.next` is the continuation ledger.

No API key, phone credential, customer PII or live mutation capability is stored in this sphere.

Qualification:

```sh
python3 -m unittest discover -s tests -v
```

## Coordination

Rasen Falcon lane: `odoo-crm-provider` (artifacts `oorexx_odoo_crm_provider` and `relationship_crm_odoo_gopher_sphere`). Current delegated qualification request: `REQ-00000689`; testing only, no coding delegation.
