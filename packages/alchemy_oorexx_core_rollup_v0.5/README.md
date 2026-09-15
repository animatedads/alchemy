# Alchemy ooRexx Core Roll-up v0.5

Repository-coordination + semantic-identity checkpoint for the resident Alchemy
ooRexx Autobuild system.

## Core rules

1. Package/domain semantics are modelled in ooRexx; transport is replaceable.
2. One `AlchemyRepositoryLease` coordinates local Git ref/object/worktree mutation.
3. Accepted-main dependencies are read from exact detached snapshots.
4. `integration.json` package name/version is semantic identity when present.
5. Directory-name identity is legacy fallback only.
6. Present malformed manifests are corruption, never silently ignored.
7. The resident service executes from an immutable runtime capsule, not the
   ordinary checkout.
8. Submission branches are transport envelopes and are never merged into main.

## Install source/core

```sh
sh install_core.sh --repo="$HOME/alchemy-autobuild/repo"
```

## Install runtime capsule / user service

```sh
sh install_runtime.sh --repo="$HOME/alchemy-autobuild/repo" --enable-now
```

Runtime capsule:

```text
~/alchemy-autobuild/runtime/alchemy_oorexx_core_v0.5/
```
