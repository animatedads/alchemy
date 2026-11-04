# NoSQLServer v0.15 transaction publication recovery

Transaction commit continues to use a staged sibling database and whole-root publication. v0.15 adds a publication intent journal before the live database root is renamed.

The journal records `liveRoot`, `stageRoot`, `backupRoot`, and the authoritative `expectedSignature`. It is written once; recovery determines the interrupted phase from the filesystem rather than depending on a phase field that might itself be torn.

Recovery rules:

- live + stage, no backup: commit may proceed only if live still equals the expected signature; otherwise discard the stale stage and preserve live;
- no live + backup + stage: verify the backup is the expected authoritative snapshot, then publish stage;
- live + backup, no stage: staged root already became live, so cleanup the old backup;
- no live + backup, no stage: staged publication cannot complete, so restore backup;
- live only plus journal: cleanup a stale journal.

This is crash-consistency recovery for the directory publication sequence. It is not a claim of distributed locking or full multi-process serializable transactions. Existing generation/signature checks remain authoritative conflict protection.
