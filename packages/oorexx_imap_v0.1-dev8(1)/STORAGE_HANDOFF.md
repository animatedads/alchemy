# Storage Fabric / ed209c handoff — IMAP dev8

The IMAP project stops at a stable mail-object/protocol boundary. Storage Fabric owns
filesystem projection, live namespace publication, transformations, caching and any
MVS/punchcard representation.

## Contract for scripts on ed209c

Automation should be able to treat mail as Storage Fabric objects/files without
speaking IMAP directly. The IMAP provider guarantees the following primitives:

* durable remote identity: account + mailbox + UIDVALIDITY + UID;
* metadata/index lookup without fetching every body;
* read access through `BODY.PEEK[]`, so indexing/materialisation does not set `\Seen`;
* safe same-server relocation through `ImapTransferOps~moveSameSession()`;
* cross-server/account recipe: APPEND -> verify -> explicit `commitSourceRemoval()`;
* exact source expunge only through UIDPLUS `UID EXPUNGE`; no global-expunge fallback;
* special-use move semantics fail closed until server-specific behaviour is qualified.

Therefore a later script may conceptually do:

```sh
find ~/mail/inbox -type f -exec grep -l 'Facebook' {} +
cp ~/mail/inbox/... ~/mvs/input/
mv ~/mail/inbox/... ~/mail/processed/
```

but the script does not need UID, MIME or punchcard knowledge. Storage Fabric maps the
filesystem operation onto the provider and transformation graph. If `~/mvs/input` is
projected as card images, that conversion remains a Storage Fabric concern.

## Move semantics exposed upward

For an ordinary mailbox on the same IMAP server:

1. MOVE capability -> `UID MOVE`.
2. No MOVE + UIDPLUS -> `UID COPY`, exact `UID STORE +\Deleted`, exact `UID EXPUNGE`.
3. No MOVE + no UIDPLUS -> deny by default; optional mark-deleted-only state is
   explicitly incomplete.

For a different server/account:

1. fetch metadata and raw bytes with PEEK;
2. APPEND destination using safe flags and INTERNALDATE;
3. verify destination according to Storage Fabric policy;
4. explicitly commit exact source removal.

This division is intentional: IMAP proves remote mail semantics; Storage Fabric turns
those semantics into scriptable namespace behaviour and, if desired, something
sufficiently perverse for an MVS job to read from virtual punchcards.
