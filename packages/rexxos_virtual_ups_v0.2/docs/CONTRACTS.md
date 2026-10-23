# Local reference contracts (v0.1)

All objects carry a schema/version string; these are **this package's** reference shapes, not a claim that a matching schema exists in the Alchemy services registry.

**State** `virtual.ups.state/1`: `name`, `capacity_ws` (watt-seconds), `remaining_ws`, `load_w`, `charge_w`, `low_pct`, `critical_pct`, `mains_present`, `logical_seconds`, `revision`. Integer state makes logical-time outcomes reproducible. The final `revision` depends on write grouping, but logical power state and event occurrences do not.

**Signals** `virtual.ups.signals/1`: `name`, `logical_seconds`, `mains_ok`, `battery_percent`, `battery_low`, `battery_critical`, `battery_empty`, `power_available`, `synthetic=true`, `guest_attached=false`. `power_available=false` is only a fictional power-loss signal; it **never stops Linux or the guest**.

**Event** `virtual.ups.event/1`: `name`, `logical_seconds`, `kind`, `synthetic=true` plus optional event-specific fields. Kinds include `simulation_initialized`, `mains_lost`, `mains_restored`, `load_changed`, `battery_low`, `battery_critical`, `battery_empty`, `battery_above_critical`, `battery_above_low`, `battery_full`.

**Journal** `virtual.ups.journal/1`: `sequence`, `action`, `params`, `events`, `previous_record_sha256`, `state_sha256`, `record_sha256`. Every read replays and verifies the journal. Hashes provide corruption detection, *not* authentication against an attacker who can rewrite all records. Back up journal separately.

**Snapshot** `virtual.ups.snapshot/1`: a full exported state, generated event history, `journal_head_sha256`, `state_sha256`, `synthetic=true`, `guest_attached=false`. Export only; restore validation/operation is a separate future gate.

**RPC**: newline-delimited JSON-RPC 2.0 on stdio as a local demonstration. Each request is exactly one line; each response likewise. Supported functions are `ups.status`, `ups.signals`, `ups.events`, `ups.audit`, `ups.snapshot`, `ups.mains`, `ups.load`, `ups.advance`. No transports or services beyond stdio are supplied.
