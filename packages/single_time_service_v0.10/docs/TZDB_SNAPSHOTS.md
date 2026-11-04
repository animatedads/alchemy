# TZif snapshot archive — single.time.service/0.8

## Provenance and representation

An archived snapshot is `snapshots/<snapshotId>/MANIFEST.tsv` plus raw
`snapshots/<snapshotId>/zones/<IANA zone identifier>` files. Identifiers are
single, bounded safe components; zone paths are checked segment by segment.
All files in an archive are copied at publication time; current host timezone
settings are not consulted by the resolver. Manifests are canonical ASCII:

```text
SINGLE_TIME_TZIF_V1|fixture-2025b|2025b
ZONE|Europe/London|SIZE|64-lowercase-hex-sha256|8-uppercase-hex-adler32
...
END|COUNT
```

Actual lines contain decimal sizes and complete digests, not placeholders.
Rows are sorted. Snapshot ID and edition are distinct: a tzdb edition can
have more than one immutable snapshot identifier because zones may be selected.
The bundled `fixture-2025b` snapshot is derived from existing package fixtures.
`synthetic-uk-fixed` intentionally maps Europe/London to an ETC/UTC TZif byte
sample; it is **only** for comparison testing and is not real IANA provenance.

## Provisioning (offline, create-only)

```bash
python3 tools/time_snapshot.py publish \
  --source /usr/share/zoneinfo --root /trusted/time-rules \
  --snapshot operations-2026a --edition 2026a \
  --zone Europe/London --zone Australia/Sydney
python3 tools/time_snapshot.py verify \
  --root /trusted/time-rules --snapshot operations-2026a
python3 tools/time_snapshot.py compare \
  --root /trusted/time-rules --from-snapshot operations-2025b \
  --to-snapshot operations-2026a
```

The edition is a publisher-supplied assertion, **not inferred or validated**
from a TZif binary. To document true IANA authority, independently retain the
release archive, download origin and signing evidence, and restrict trust to
approved administrators. The provided tool checks the SHA-256 over every
archived zone's exact bytes. It rejects altered bytes and does not overwrite an
existing named snapshot. It is not a replacement for authenticated publishing.

## Native ooRexx use

```rexx
::requires 'TimeRuleSnapshots.cls'
catalog=.TimeRuleSnapshotCatalog~new('/trusted/time-rules')
old=catalog~loadService('operations-2025b',.array~of('Europe/London'))
new=catalog~loadService('operations-2026a',.array~of('Europe/London'))
/* the existing analyzer accepts old and new separately */
review=.TimeImpactAnalyzer~new(authorityLedger,old,new)
```

Native loading verifies size and Adler32 against the locally read manifest,
then calls `TzifZoneProvider~loadBytes` on those exact bytes. This avoids a
second TZif file read between consistency check and parsing. The publisher's
SHA-256 is not revalidated inside ooRexx. The directory must be protected
against malicious concurrent filesystem mutation and checked before use.
The native `inspect(snapshotId)` method returns archive metadata, not an
attestation. `loadService(snapshotId, selectedZones)` never accepts remote
filesystem path arguments, and snapshot selection is trusted local policy.

## Semantics and operational boundaries

- Snapshots belong to Time Service's rule-data authority, not to RPC or
  ConnectSelector; no new communication adapter or transport introduced.
- Calendar revisions and TZDB snapshots are independent. A replay fixes both.
- Impact analysis remains bounded, read-only and advisory. No push, queue
  dispatch, subscription, timeout, or automatic recurring-event modification.
- Historical TZif future-rule horizon limitations remain.
- Trusted publication can be externally scheduled; this package contains no
  background updater or clock synchronisation and no cryptographic signature.
- This is not a multi-writer distribution registry, and does not implement
  cross-machine replication, policy signing or filesystem monitoring.
