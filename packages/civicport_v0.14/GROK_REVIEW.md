# CivicPort v0.14 — reviewer handoff

## Review question

Does v0.14 expose durable SWIM/NOTAM evidence through SQL and Runtime Registry
without turning either surface into transport authority or operational NOTAM
truth?

## Expected properties

1. `CivicNotamJournalProjector` reads existing `CivicQueueJournal` records only.
   It does not claim/ACK/NACK/release Queue Fabric work and has no JMS or Secret
   Broker code.
2. Supported runway-closure records become
   `faa.swim.aim-fns.notam-runway-closure/0.1` projections. Unsupported records
   remain explicit diagnostics with journal record/source identity and failure
   stage.
3. `CivicNotamRelationProvider` exposes a 27-column read-only relation. The
   first SELECT freezes the snapshot; later journal appends do not mutate it.
4. Runtime ability `civic.notam.runway-closure.evidence` accepts exactly
   `source_identity`. It rejects queue names, journal paths, JMS selectors, URLs
   and credential references.
5. The 10-digit FAA time tokens remain lexical JSON strings. There is no
   numeric coercion, DateTime conversion, century inference, timezone inference
   or active/inactive calculation.
6. Both surfaces retain `NOT_FOR_OPERATIONAL_USE` and
   `EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE`. No NOTAM HardWorld promotion rule
   exists.
7. CivicPort pins the consolidated JMS bridge `0.1-dev7-fb1` only for the
   unchanged Java-neutral TEXT/persistence boundary inherited from dev6. Its
   FederationBank/MapMessage additions are irrelevant to CivicPort.

## Current baseline

`oorexxapis(20260828-141725).zip` SHA-256:
`a130157f425ac71f734a217b7dfd4a111bad356bc9633516c15d5f258d95c4b2`

Key dependency hashes:

```text
alchemy_objects_v0.8.zip
  7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073
oorexx_crypto_v0.3.zip
  20445a2dec92b53f47f27aefe73783f81f24ebf86bfbabaa2c2adfd15823ab59
runtime_registry_v0.14.zip
  b8748634f271f5389b9e7e4fd7089eda314b0eea90ab6e47151ae1de270c6209
nosqlserver_v0.79.zip
  076e6c6dafe367862ee25d5fcf80bef2eb3a5337060d3d2f55bba2f55327a1ec
structured_relation_plugin_v0.9_compat_20260824.zip
  22d72db2072b1fa49aebc50a3a76e5c74cf0cc0dee35f01050699a2acfa06c21
oorexx_queue_fabric_v0.9-dev4.zip
  9c1487f8dc878ae21a19e8fc8a139c801a80a97acd2c6575635003e6f8069898
oorexx_jms_queue_bridge_v0.1-dev7-fb1.zip
  bf0c742f8f8e95e8d5b10dca67b92641780b8938417a2fd508192f27ccc26622
oorexx_secret_broker_v0.2.zip
  c063a8e863547e8d5af427daee9b887590fdad76a65bc042b8f853acfd51e623
virtual_ryta_hardworld_v0.31_work.zip
  8263151d1f04ec580220a4a60dfaa9820dcb477b5f93d464102bb0c706fb14f7
```

## Reviewer attacks worth trying

- Append one supported runway closure and one taxiway notice: SQL should expose
  one typed row and one explicit diagnostic.
- Append another valid record after first SELECT: the existing relation must
  remain frozen; a fresh relation should see both valid records.
- Add `journal_root`, `queue_name`, `jms_selector`, `url` or
  `credential_reference` to Runtime input: exact schema must reject it.
- Try to infer current activity from `2608261100-2608270001`: no such field or
  method should exist.
- Search the three new v0.14 NOTAM surface files for JMS provider, Secret Broker,
  Queue ACK/NACK/claim, HardWorld or promotion dependencies: none should exist.

## Fixture honesty

The JYR AIM-FNS XML remains synthetic deterministic test data. It is not a live
FAA capture and this package makes no operational-suitability claim.
