# oorexx.atomic-file/0.1

## AtomicFileOptions

Fields: `durability`, `noFollow`, `preserveMode`, `mode`, `expectedGeneration`, `backupPolicy`.

Dev1 supports durability `NONE|DATA|FULL`, target no-follow, mode preservation and `backupPolicy=NONE`.

Setting `expectedGeneration` or another backup policy fails closed because dev1 cannot provide those semantics race-free.

## AtomicFile

- `replace(path, bytes [, options]) -> AtomicFileResult`
- `provider`
- `capabilities`

## AtomicFileResult

Fields include `ok`, `published`, `durabilityRequested`, `durabilityAchieved`, `fileSynced`, `parentSynced`, `bytes`, `mode`, `replacedExisting`, provider/error fields.
