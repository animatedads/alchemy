# MVS Alchemy Storage-Fabric DSFS-like personality v0.1

This personality presents Storage Fabric namespace objects to MVS applications as
USS/zFS-looking `PATH=` resources without claiming that MVS 3.8J implements z/OS
USS, zFS or IBM DSFS.

Example guest intent:

```jcl
//MYZFSFILE DD PATH='/u/USER/sample.txt',
//             PATHOPTS=ORDONLY,
//             FILEDATA=TEXT
```

Authority split:

- MVS Alchemy owns DD/PATH/PATHOPTS/FILEDATA/session/error semantics.
- Storage Fabric owns StorageRef identity, namespace projection, object catalogue,
  byte provider selection, persistence, versioning and movement.
- Hercules owns device presentation only.

A successful write creates a new StorageRef and advances the namespace binding.
The previous object remains independently addressable in the Storage catalogue.

Views:

- TEXT: normalized host text; AWS tape projection emits EBCDIC CP037 records.
- BINARY: exact bytes, split into bounded tape blocks when projected.
- RECORD: Alchemy `MVS_RECORD_STREAM_V1` (4-byte BE length + record bytes).

Directory-to-tape:

1. Resolve/list the Storage Fabric directory.
2. Pin each current StorageRef into a manifest.
3. Emit a Hercules AWSTAPE image.
4. Tape file 1 is `MASDIR 1`, an EBCDIC manifest.
5. Each subsequent Storage object is one logical tape file, separated by tape marks.

The AWS image is a projection, not storage authority. Recreating it from the same
manifest/StorageRefs is valid; changing a namespace path after projection does not
silently change the tape already produced.

## Live round-trip gate

The fixture proves object/view/tape semantics, not guest interception. The live
acceptance sequence is deliberately separate:

```text
StorageRef A -> /u/USER/sample.txt
 -> ED209Z or ED209ZZ PATH read
 -> guest write/close
 -> StorageRef B
 -> project /u/USER to AWS
 -> Hercules DEVINIT tape-unit image.aws
 -> MVS tape read
 -> compare bytes/records against StorageRef B
```

A live run passes only if the final MVS-observed content corresponds to the
pinned StorageRefs in the MASDIR manifest; namespace retargeting after tape
creation must not alter the already-created tape image.
