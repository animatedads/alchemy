# Plan42 — RX2CPP path and compiler-tree integrity, dev6 (2026-10-29)

## Scope

A bounded, read-only source-qualification fix to Plan42's existing `plan42.native.plan` operation. The native compiler continues to be implemented in ooRexx by RX2CPP. This change neither edits RX2CPP nor claims to compile native C++ successfully.

## Discovered defects and fixes

1. dev5 checked `src.is_symlink()` and the generated-root directory, but not an intermediate directory such as `generated/plan42/alias/file.rex` pointing to a real folder *inside* generated. The path resolves inside the allowed boundary but its lexical meaning can be changed by replacing the link. `has_workspace_symlink()` now examines **every component** under the workspace and refuses `..` path traversal. It is also applied to receipt files. There is no claim to prevent races against a concurrent filesystem writer.
2. dev5 verified only seven named API files against their committed Git blobs. `oorexx2cpp/rules/*.cls`, native headers, other helper files and newly created tools could still change compiler behaviour. `check_checkout_interfaces()` now calls `git status --porcelain=v1 --untracked-files=all -- oorexx2cpp` and refuses compiler-tree changes, in addition to exact seven-interface content verification. An unrelated untracked documentation file outside `oorexx2cpp` does not block the compiler.
3. The `compiler_tree_clean` outcome is **not an entire-execution environment seal**. Git-ignored content, external dependencies, environment variables, symlink replacement after checking and interpreter/native binaries require separate scrutiny. This is a stronger preflight guard, not the full runtime/parity gate.

## Run

```sh
cd packages/plan42_alchemy_bridge_v0.1-dev6
python3 -m unittest discover -s tests -p 'test_plan42*.py' -v
python3 -m py_compile tools/*.py
```

## Version and publication policy

- New release: `plan42_alchemy_bridge 0.1-dev6`, versioned path, no replacement of dev4 or dev5.
- RX2CPP upstream pin remains `9047f0e13c8cd67acf4258bd69cf78ea946944ac` with explicit observed candidate `e3d8d0024943565eb3d247b2c02a8a955f6a7f01`, not auto-promoted.
- `READY_FOR_DIFFERENTIAL_QUALIFICATION` is not a deployment certificate. Native ooRexx 5.3/GCC/Clang parity, approved source revisions and runtime publication need separate evidence and authorisation.
- Autobuilder was explicitly reported stopped; direct Git publication of this new versioned source package does not represent an Autobuild PASS.
