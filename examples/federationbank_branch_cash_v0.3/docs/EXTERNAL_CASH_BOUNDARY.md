# External cash boundary

Branch Cash v0.3 adds a neutral vault-side instruction for physical cash crossing the branch perimeter. It deliberately does not own the carrier/cash-centre shipment lifecycle.

An external vault movement requires all of:

1. exact external shipment identity;
2. upstream External Cash authority reference;
3. current vault primary custodian;
4. current vault independent control custodian;
5. Branch Cash policy approval;
6. denomination-counted physical bundle matching the instruction.

The shipment ID is idempotent at the vault boundary so the same completed external movement cannot alter expected cash twice.
