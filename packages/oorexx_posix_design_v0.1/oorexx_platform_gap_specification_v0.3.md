# ooRexx Estate Platform Gap & Reuse Specification

**Review basis:** static architectural review of the supplied ooRexx estate. No ooRexx interpreter was used and no runtime behaviour is asserted from execution. The review intentionally looks for repeated *responsibilities*, not merely duplicate text.

**POSIX revision basis (v0.3):** the POSIX recommendations were additionally checked against the supplied ooRexx 5.3.0 r13196 package, including the shipped `RxUnixSys` Unix Extensions library (`::requires "rxunixsys" LIBRARY`) and RexxUtil file functions. The platform design below therefore treats those facilities as existing authority and adds wrappers or new native primitives only where their contracts are insufficient.

## 1. Executive conclusion

The estate does **not** primarily suffer from a shortage of reusable components. It suffers from four related problems:

1. **Existing platform components are bypassed.** The clearest example is provider-specific `curl` transports despite a capable `oorexx_api_client_v0.4.1` that already owns HTTP parsing, sockets and native TLS.
2. **Platform-worthy infrastructure remains application-local.** POSIX metadata, process execution, archive handling, atomic-file publication and file quiescence are repeatedly implemented inside applications.
3. **Delivery vendoring is leaking into source authority.** Identical and older copies of Queue Fabric, Crypto, Alchemy Objects, Wire UI, Accounting and Journal Pointed State appear in application trees. Vendoring is acceptable for sealed delivery; it should not define development ownership.
4. **Built-in ooRexx facilities are used inconsistently.** Some code correctly uses `.JSON`, `.Yaml` and `.CSVStream`; other code hand-frames TSV, shells to external tools, or implements local wrappers for functionality already available in the estate.

The target architecture should therefore have a small, explicit **Platform Foundation** layer. Applications depend on it; they do not reimplement it.

---

## 2. Static evidence summary

The supplied archives expand into a large multi-version corpus. Raw counts below deliberately include versioned and vendored copies because duplication is itself one of the findings.

- 246 nested ZIP components were found in the supplied extracted material.
- 4,561 Rexx-like source files (`.cls`, `.rex`, `.rexx`, `.rxj`, `.sh`) were scanned across the top-level packages and expanded nested packages.
- 4,074 unique source contents were identified by SHA-256.
- 416 duplicate-content groups contained 903 source files.
- 294 `ADDRESS SYSTEM` occurrences were found across 144 Rexx source files.
- 45 locally defined shell-quoting methods were found across 38 source files.
- 98 `SysTempFileName` uses were found across 49 source files.
- 510 literal tab-delimiter constructions (`"09"x` / `'09'x`) were found across 62 source files, while `.CSVStream` appeared in only 10 source files.
- 108 `curl` references occurred across 31 Rexx source files; the important production examples are detailed below.
- 34 `sha256sum` references occurred across 18 source files despite the Crypto estate already providing streaming SHA-256.

These numbers are *signals*, not defect counts. Tests, compatibility code, explicitly external integrations and sealed delivery trees can be legitimate. The specification below distinguishes those cases.

---

## 3. Existing platform components: make these authoritative

### 3.1 `oorexx_api_client_v0.4.1` — authoritative outbound HTTP/TLS client

**Status:** Exists; promote to mandatory default.

`ApiHttpTransport.cls` explicitly states that it is not a curl subprocess wrapper. It contains URL handling, HTTP codec/parser logic, socket I/O and a native TLS path using Foreign Runtime/OpenSSL bridges. It also has HTTP/2 support through a native bridge.

**Rule:** Application and provider code MUST NOT shell to `curl` for ordinary HTTP/HTTPS. A provider may supply an alternate transport only when the protocol capability is genuinely absent from API Client and the exception is documented.

**Refactor targets:**

- `oorexx_ai_provider_grok_v0.4/src/GrokProvider.cls` — `GrokCurlTransport` around lines 231+.
- `oorexx_ai_provider_grok_v0.4/src/GrokBatchProvider.cls` — curl-backed batch transport.
- `oorexx_ai_provider_openai_compat_v0.5/src/OpenAICompatProvider.cls` — `OpenAICompatCurlTransport` around lines 225+.
- `oorexx_ai_provider_anthropic_v0.2/src/AnthropicTransport.cls` — creates body/config/output files then calls curl around lines 126–169.
- `civicport_v0.14/src/CivicHttpPort.cls` — `CivicCurlTransport` around lines 146–213.
- top-level LLM PA `src/LlmPaExternalProviders.cls` line 33 — explicitly instantiates `.OpenAICompatCurlTransport~new("curl", ...)` even though LLM PA's native Ollama path already uses API Client/RxSock correctly.
- Psychic Poker and FlyLo provider adapters containing their own curl paths.

**Required enhancement:** add first-class provider conveniences to API Client rather than allowing each provider to rebuild them:

- JSON request/response helper preserving `.JsonString`, `.JsonBoolean`, `.JsonNull` semantics.
- Secret Broker header injector that materializes a lease only inside the transport call.
- bounded request/response body handling.
- retry policy object with idempotency classification.
- rate-limit header observation.
- streaming/SSE facade.
- request evidence object with endpoint origin, method, status, timing and transport identity but no secret material.

### 3.2 `oorexx_crypto_v0.8.3` — authoritative cryptography and digest layer

**Status:** Exists; extend with a simple file/stream facade and eliminate command-line digest tools.

`crypto.cls` already implements streaming hashes and `CryptoStream`. Shelling to `sha256sum` is therefore generally platform debt, not a missing capability.

**Refactor targets include:**

- `oorexx_storage_fabric_v0.1-dev7/src/StorageStreaming.cls` lines ~342–365 (`StoragePosixSha256Verifier`).
- top-level Storage Evacuation `EvacLocalReplicaExecutor~safeName` around lines ~595–603.
- LLM PA `LlmPaPackageRelease.cls` line ~16 and `LlmPaPackageStage.cls` lines ~190, ~268.
- Semantic Source Control digest paths.
- KL10 tool scripts that repeatedly invoke `sha256sum`.
- `CivicDigestPort`, which shells to a digest executable.

**Required enhancement:** provide one boring, obvious API so application authors never have a reason to use `sha256sum`:

- `.CryptoFile~sha256(path [, chunkBytes])`
- `.CryptoFile~sha512(path [, chunkBytes])`
- `.CryptoStreamDigest~new("SHA256")~update(bytes)~digest`
- digest evidence containing algorithm, byte count and provider identity.

The implementation should use the existing streaming Crypto API and optionally the Foreign Runtime accelerator. It MUST remain bounded-memory.

### 3.3 `json.cls`, `yaml.cls`, `csvStream.cls` — authoritative data serialization

**Status:** Built-in/stdlib capability; mandate use.

Good examples already exist:

- QueueRexx `QueueRexxSerialization.cls` delegates YAML to `.Yaml` and TSV to `.CSVStream` with delimiter `'09'x`.
- `FDDoorMicroMotion.cls` uses `.CSVStream` with the tab delimiter for checkpoint/manifests/output shards.
- Runtime Registry, MCP, Accounting and many others use `.JSON~toJSON` / `.JSON~fromJSON` correctly.

**Rule:** Do not write application-local JSON encoders/decoders or tab split/join codecs for general records. TSV is CSV with a tab delimiter unless there is a documented canonical-wire reason otherwise.

**Refactor targets:**

- LLM PA `LlmPaCore.cls` around lines ~82 and ~304 manually builds/parses hex-escaped TSV memory rows.
- LLM PA `LlmPaContinuity.cls`, `LlmPaWorkflow.cls` and `LlmPaPlan.cls` manually frame tab records.
- Storage Fabric `StorageCodec` and multiple persistence records manually concatenate/split `'09'x` around lines ~272 and ~321–343 and later state records.

**Exception:** cryptographically canonical or backward-compatible wire formats may keep a dedicated codec, but that codec must be a single documented library boundary and not copied into consumers.

### 3.4 `RxUnixSys` + RexxUtil — authoritative Unix/POSIX primitive layer

**Status:** Ships with ooRexx 5.3.0; use it before writing another libc binding.

The supplied ooRexx package contains `librxunixsys.so` and the Unix Extensions reference. Programs gain the library with:

```rexx
::requires "rxunixsys" LIBRARY
```

`RxUnixSys` already maps a substantial set of Unix APIs directly into Rexx. The important existing coverage is:

| Area | Existing ooRexx Unix functions | Platform decision |
|---|---|---|
| Process/thread identity and signalling | `SysGetpid`, `SysGetppid`, `SysGettid`, `SysKill`, `SysGetpgrp`, `SysSetpgid`, `SysSetsid` | Reuse. Do not bind these libc calls again. |
| Credentials and account lookup | `SysGetuid`, `SysGeteuid`, `SysGetgid`, `SysGetegid`, `SysGetpwnam`, `SysGetpwuid`, `SysGetgrnam`, `SysGetgrgid`, set-uid/gid variants | Reuse behind a typed credentials/account facade. |
| Basic filesystem mutation | `SysChmod`, `SysChown`, `SysLchown`, `SysLink`, `SysSymlink`, `SysMkdirUnix`, `SysRmdirUnix`, `SysUnLink`, `SysUmask` | Reuse. Do not shell to `chmod`, `chown`, `ln`, `mkdir`, `rmdir` or `rm` for these primitives. |
| Filesystem observation | `SysAccess`, `SysEuidaccess`, `SysGetdirlist`, `SysStat` | Reuse where the existing contract is strong enough. |
| Extended attributes | `SysGetxattr`, `SysListxattr`, `SysSetxattr`, `SysRemovexattr` where supported | Reuse, with capability detection and a facade that normalises weak error signalling. |
| Error/system information | `SysGeterrno`, `SysGeterrnomsg`, `SysUname`, `SysGethostname` | Reuse for POSIX result/evidence objects. |

RexxUtil also already owns ordinary cross-platform file mechanics such as `SysFileCopy`, `SysFileDelete`, `SysFileExists`, `SysFileMove`, `SysFileTree`, `SysGetFileDateTime`, `SysSetFileDateTime`, `SysMkDir`, `SysRmDir`, `SysTempFileName`, and on Unix-like systems `SysCreatePipe`. These should be preferred when their semantics match the requirement.

**Loading rule:** new code should normally use the documented package directive rather than dynamically registering individual Unix functions. The current Queue Fabric source contains `RxFuncAdd("SysMkDir", "rxunixsys", "SysMkDir")`; unless optional runtime discovery is genuinely required, the cleaner foundation is `::requires "rxunixsys" LIBRARY` plus the documented collision-safe Unix names such as `SysMkdirUnix` / `SysRmdirUnix`. If optional discovery is required, hide it inside the POSIX provider rather than exposing it to domain code.

**Important boundary:** existing functions are not automatically sufficient for all fidelity or durability work. In particular:

- `SysStat` returns one selected field per call. Repeated calls cannot provide a single coherent metadata snapshot if a file changes between calls. Storage Evacuation therefore needs a one-syscall structured stat primitive rather than building a `PosixStat` by repeatedly calling `SysStat`.
- the documented Unix API has no `lstat`/`fstatat` structured result or `readlink`, so exact symlink-preserving inventory still has a gap.
- `SysGetdirlist` returns an empty array both for an empty directory and for an open failure; the platform facade must turn this into an explicit success/error result.
- xattr getters use empty values/arrays as failure indicators, which is too weak for evidence-grade code where an empty attribute value can be legitimate; capture `errno` immediately and normalise it.
- `SysStat`/RexxUtil date APIs expose second-resolution textual timestamps, not the nanosecond-preserving `timespec` data required for exact metadata replay.
- no shipped primitive in the reviewed Unix Extensions contract supplies POSIX ACLs, `statvfs`, sparse extents, `fsync`/`fdatasync`, secure `openat`/`*at` no-follow operations, or a crash-durable rename protocol.
- process signalling/identity exists, but argv-first spawning, `waitpid`, child stdio wiring and bounded capture do not.

**Rule for new POSIX work:** there are three layers, in this order:

1. use `RxUnixSys` or RexxUtil unchanged when the shipped contract is sufficient;
2. extend `RxUnixSys` with a missing generally useful Unix primitive where that is the natural long-term ooRexx home;
3. use Foreign Runtime only for genuinely absent or specialist capabilities, behind the same platform facade.

Do **not** make `oorexx_posix` a second wholesale libc binding. Its job is to supply typed objects, coherent error handling, capability reporting, policy/safety semantics and higher-level operations over the Unix primitives ooRexx already provides.

Recommended additions to `RxUnixSys` itself, if the estate is willing to carry or upstream them, are `SysStatInfo` (one native stat call returning all fields), `SysLstatInfo`, `SysFstatatInfo`, `SysReadlink`, `SysUtimensat`, `SysStatvfs`, `SysFsync`/`SysFdatasync`, and the small set of `*at` operations required for race-resistant no-follow mutation. POSIX ACL support can remain a libacl-backed optional provider because it is not a libc/POSIX-base primitive on every target.

### 3.5 Other components that should remain platform-owned

Do not create competing application-local versions of:

- Queue Fabric (`oorexx_queue_fabric_v0.9-dev5`)
- Storage Fabric (`oorexx_storage_fabric_v0.1-dev7`)
- Secret Broker (`oorexx_secret_broker_v0.2`)
- Logging (`oorexx_logging_v0.7`)
- Observation (`oorexx_observation_v0.5`)
- Runtime Registry (`runtime_registry_v0.14`)
- Runtime Reference (`runtime_reference_v0.4`)
- Foreign Runtime (`oorexx_foreign_runtime_v0.22.6`)
- Unix Socket (`oorexx_unix_socket_v0.6`)
- Lazy Read File (`oorexx_lazy_read_file_v0.1-dev1`)
- Journal Pointed State (`oorexx_journal_pointed_state_v0.1`), extended as described below.

---

## 4. New platform libraries to write

### 4.1 `oorexx_process` — **P0**

**Why:** Process execution is currently replicated all over the estate. QueueRexx has `QueueCommandExecutor`, Alchemy has `AlchemyCommandRunner`, LLM PA has command bridges/runners, provider adapters have `runShell`, and many classes define their own shell quoting.

**Placement:** `oorexxapis/current/oorexx_process_v0.1/`

**Core contract:**

```text
ProcessSpec
  argv: Array                   mandatory
  cwd: String | nil
  environment: Directory       explicit overlay
  stdin: bytes/stream/nil
  stdoutPolicy: capture/stream/inherit/discard
  stderrPolicy: capture/stream/inherit/discard
  timeoutMs
  maxOutputBytes
  detach
  processGroup
  secretArguments: forbidden by default

ProcessRunner~run(spec) -> ProcessResult
ProcessRunner~spawn(spec) -> ProcessHandle
ProcessHandle~pid / wait / terminate / kill / alive / startIdentity
```

**Implementation boundary:** do not duplicate the process primitives already supplied by `RxUnixSys`. Unix providers should use `SysGetpid`, `SysGetppid`, `SysGettid`, `SysKill`, process-group/session functions and the Unix credential functions where applicable. RexxUtil `SysCreatePipe`, `SysFork` and `SysWait` should be used where their simple pipe/fork/wait contracts are sufficient.

RexxUtil additionally supplies `SysFork()` and `SysWait()`, so fork/wait are not wholly absent. Reuse them where their simple contracts are sufficient. The remaining platform gap is **managed process creation and supervision**: argv-preserving spawn/exec, targeted `waitpid`-class waiting, child stdio actions, cwd/environment setup, timeout/cancellation and reliable start identity. The preferred native implementation is `posix_spawn[p]` plus file actions where the target supports it; `SysFork()` remains useful for direct fork semantics but does not replace an argv-safe execution API. These missing primitives may initially be supplied by Foreign Runtime; if they prove generally useful, they should move down into the ooRexx Unix/RexxUtil layer rather than remain duplicated bindings forever.

The normal path MUST NOT invoke a shell. A separate explicit `ShellCommand` adapter may exist for the few integrations that genuinely require shell language semantics.

**Required properties:**

- argv preserved exactly; no quoting problem exists on the normal path.
- bounded stdout/stderr capture and streaming.
- timeout and cancellation.
- cwd and environment without `cd &&` string construction.
- detached/process-group lifecycle using the existing Unix process-group/session primitives where possible.
- process start identity to prevent PID-reuse errors. On Linux this may include `/proc/<pid>/stat` start time evidence; that is a Linux provider detail, not QueueRexx business logic.
- redacted diagnostic rendering.
- platform capability registration via Runtime Registry.

**Consumers:** QueueRexx, Alchemy, LLM PA, Storage Evacuation, Semantic Source Control, terminal/machine runners, test harnesses.

### 4.2 `oorexx_posix` — **P0**, primarily an OO facade over `RxUnixSys`

**Why:** Storage Evacuation and QueueRexx shell to Unix commands for filesystem and ownership behaviour that is partly already available natively through ooRexx. The platform hole is therefore **not** “ooRexx has no POSIX support”; it is that applications do not have one typed, evidence-grade facade which first consumes `RxUnixSys`/RexxUtil and then fills the remaining fidelity gaps.

**Placement:** `oorexxapis/current/oorexx_posix_v0.1/`

**Detailed design:** see `oorexx_posix_v0.1_design_spec.md`. It defines the exact RxUnixSys/RexxUtil reuse matrix, coherent-stat requirement, descriptor-relative traversal boundary, capability model, error normalization, qualification cases and minimal RxUnixSys extension set.

**Core objects:**

```text
PosixCapabilities
PosixResult / PosixError
PosixCredentials / PosixUser / PosixGroup
PosixPath
PosixStat / PosixFileIdentity
PosixDirectoryIterator
PosixExtendedAttributes
PosixAcl
PosixFileTimes
PosixLink
PosixFileMutation
PosixFilesystemInfo
```

**Provider order:**

```text
RxUnixSys provider     # default for covered Unix primitives
RexxUtil provider      # ordinary portable file operations where semantics fit
RxUnixSys-extended     # new generally useful Unix primitives, when available
Foreign Runtime        # only remaining gaps / optional libraries such as libacl
```

**Operations already covered and therefore wrapped, not reimplemented:**

- access checks -> `SysAccess` / `SysEuidaccess`;
- chmod/chown/lchown -> `SysChmod` / `SysChown` / `SysLchown`;
- basic directory listing -> `SysGetdirlist`;
- hard/symbolic link creation -> `SysLink` / `SysSymlink`;
- mkdir/rmdir/unlink -> `SysMkdirUnix` / `SysRmdirUnix` / `SysUnLink` (or RexxUtil equivalents where the portable semantics are desired);
- basic stat fields -> `SysStat`;
- xattr get/list/set/remove -> existing `Sys* xattr` functions;
- ordinary copy/move/delete/existence/date operations -> RexxUtil where no stronger POSIX guarantee is required.

**True gaps which still need new primitive support:**

- coherent one-call `stat` object and `lstat`;
- `fstatat`/no-follow `*at` family for race-resistant traversal and mutation;
- `readlink`;
- nanosecond file times and `utimensat`;
- POSIX ACL get/set where libacl is present;
- `statvfs`/filesystem capacity and identity, replacing `df` parsing;
- sparse extent discovery (`SEEK_DATA`/`SEEK_HOLE` or provider equivalent);
- fsync/fdatasync and parent-directory sync required by durable publication;
- secure open/no-follow primitives required by AtomicFile and hostile-tree traversal.

**Critical Storage Evacuation requirement:** `PosixStat` MUST represent one coherent observation. It must not call `SysStat(path, ...)` ten times and pretend those values came from one metadata generation. Until a structured one-call stat primitive exists, the Storage Evacuation migration should keep its current isolated probe or use a small gap provider for stat/lstat rather than weakening its fencing semantics.

**Error model:** low-level `-1`, empty string and empty array conventions are normalised immediately into `PosixResult`/`PosixError` objects. `errno` and its text are captured before any subsequent native call can overwrite them. Domain code should not need to know which primitive used which failure convention.

**Capability model:** xattrs, ACLs, sparse extents and Linux-specific observations are explicit capabilities. Absence is reported; it is never silently replaced with a subprocess.

**Consumers:** Storage Evacuation first; QueueRexx ownership/diagnosis second; package/release tooling third.

### 4.3 `oorexx_atomic_file` — **P0/P1**

**Why:** Temp-write-move publication is repeated in CivicPort, NoSQLServer, QueueRexx, LLM PA and other packages. Most local versions do not express the durability contract (fsync file? fsync parent? same-filesystem rename? permissions? crash point?).

**Placement:** either standalone `oorexx_atomic_file_v0.1` or a clearly separated subpackage of `oorexx_posix`. Use RexxUtil `SysTempFileName` / `SysFileMove` only for non-durable convenience paths; crash durability still requires the stronger fsync/rename/no-follow contract below.

**Contract:**

```text
AtomicFile~replace(path, bytes, options)
AtomicFile~writeWith(path, callback, options)
AtomicDirectory~publish(stagingDir, liveDir, options)
```

Options must cover mode/owner inheritance, fsync policy, backup policy, no-follow semantics and expected-current-generation.

**Rule:** code should no longer hand-roll `SysTempFileName` + write + `SysFileMove` for durable state.

### 4.4 `oorexx_archive` — **P1**

**Why:** LLM PA shells to `zip`/`unzip`; Alchemy defines `AlchemyZipArchive` on top of `unzip`; Semantic Source Control also shells to `unzip`; FD Door Micro Motion shells to `tar` for migration bundles.

**Placement:** `oorexxapis/current/oorexx_archive_v0.1/`

**Implementation:** Foreign Runtime bridge to libarchive is the preferred platform implementation.

**Required functionality:**

- list archive without extraction.
- bounded safe extraction.
- create ZIP and tar variants.
- deterministic/reproducible archive mode (stable ordering, timestamp policy, uid/gid policy).
- reject absolute paths, `..` traversal, device nodes and disallowed symlinks.
- expansion ratio/byte/file-count limits.
- streaming entry access.
- caller-provided content digest/evidence hooks.

This removes command parsing and gives every package the same archive safety semantics.

### 4.5 `oorexx_file_quiescence` / `oorexx_snapshot_authority` — **P0 for backup/evacuation work**

**Why:** Storage Evacuation correctly probes metadata before and after transfer and refuses to claim the newer generation if it changed. That detects many races, but it does **not** prove that a file was not open for write during the copy. A writer can hold a descriptor open while the file happens to remain unchanged across the probe interval.

**Placement:** `oorexxapis/current/oorexx_file_snapshot_v0.1/`.

**Authority model:**

```text
SnapshotAuthority~acquire(source, policy) -> SnapshotLease
SnapshotLease~strength
  APPLICATION_QUIESCED
  FILESYSTEM_SNAPSHOT
  COOPERATIVE_LOCKED
  OPEN_WRITER_NEGATIVE_EVIDENCE
  STABLE_WINDOW_ONLY
SnapshotLease~evidence
SnapshotLease~release
```

**Providers:**

- application-specific quiesce provider (databases, services) — strongest and preferred.
- filesystem snapshot provider (LVM, Btrfs, ZFS, cloud snapshot APIs).
- cooperative advisory-lock provider where the writer participates.
- Linux open-writer observation provider using native `/proc`/kernel interfaces as evidence, explicitly not absolute proof.
- stable-window provider (current Storage Evacuation technique) as the lowest assurance class.

**Important:** never collapse these assurance levels into one boolean `stable=true`. Backup correctness depends on knowing what kind of snapshot was actually obtained.

### 4.6 `oorexx_durable_state` — **P1; evolve Journal Pointed State rather than inventing another journal**

**Why:** there are many application-local audit/journal/state classes. The estate already has Journal Pointed State, so the correct move is to generalise it into a durable-state substrate.

**Placement:** evolve `oorexx_journal_pointed_state` or supersede it explicitly with `oorexx_durable_state_v0.1` while preserving adapters.

**Required facilities:**

- append-only framed journal.
- monotonically ordered sequence/generation.
- checksum/digest per frame.
- atomic pointed snapshot publication.
- recovery/truncation policy for torn tails.
- compaction with provenance.
- optional JSON/YAML/CSVStream codecs supplied as adapters, not reimplemented.
- lock/lease integration.
- schema/version identifier per record stream.

Consumers should keep domain semantics but stop reimplementing the persistence mechanics.

### 4.7 `oorexx_package_resolver` — **P1**

**Why:** source trees contain exact copies and stale vendored versions of core libraries. Examples found include current Queue Fabric v0.9-dev5 alongside test-app vendored dev4, current Accounting Core v0.10 alongside vendored v0.7, and current Crypto v0.8.3 alongside older vendored Crypto trees.

**Placement:** `oorexxapis/current/oorexx_package_resolver_v0.1/`, integrated with Runtime Registry/Alchemy package metadata rather than creating a second authority system.

**Development rule:** one authoritative source tree per component/version. `::requires` resolution comes from a generated runtime/package path, not copied source.

**Release rule:** a release assembler MAY vendor exact dependency sources into a sealed artifact, but must generate a dependency lock manifest recording component id, version, digest and source provenance. Vendored files are generated output and never edited in place.

### 4.8 `oorexx_remote_execution` — **P2**

**Why:** LLM PA and some storage/job code contain direct SSH assumptions. The estate already has Queue Fabric, Job-to-Node and QueueRexx remote execution concepts.

**Contract:** submit an execution request through a provider-neutral interface; SSH can be one provider, not application protocol.

The API should carry identity, node/placement authority, timeout, input/output evidence, exit status and policy result. This prevents each application from inventing SSH quoting, key selection and lifecycle semantics.

---

## 5. Design choices to classify as poor or risky

### 5.1 Provider-specific `curl` transports — **poor design, high priority**

Why:

- duplicate TLS/HTTP/error/timeout/header behaviour.
- subprocess and temp-file complexity.
- secrets are forced through a curl-specific materialisation dance.
- inconsistent observability and retry semantics.
- bypasses API Client, which already exists specifically to own this boundary.

Action: migrate all ordinary provider traffic to API Client. Keep curl only as an explicit diagnostic/compatibility provider outside the default runtime.

### 5.2 `sha256sum` for application hashing — **poor design, high priority**

Why: Crypto already contains streaming hashes. External hashing creates executable/path assumptions and duplicate capture/parse code.

Action: add `.CryptoFile` convenience facade and remove normal `sha256sum` use.

### 5.3 Repeated shell quoting — **architectural smell, high priority**

Why: 45 local quoting methods exist in the scanned corpus. Correct quoting is not a business-domain responsibility.

Action: `oorexx_process`, argv-first, no shell.

### 5.4 Manual general-purpose TSV framing — **poor design unless canonical-wire exception applies**

Why: `.CSVStream` already supports alternate delimiters and handles quoting/escaping. Manual `"09"x` concatenation creates one-off escaping rules and schema ambiguity.

Action: use a small shared `DelimitedRecords` facade over CSVStream, with named schema/version where persistence is durable.

### 5.5 Vendored dependencies as editable source — **poor source-control design**

Why: fixes do not propagate, old versions silently survive and duplicate classes can be loaded accidentally.

Action: central authority + lock manifest + release-time vendoring only.

### 5.6 Repeated temp-file + move atomicity — **risky durability design**

Why: rename alone is not a complete crash-durability contract and behaviour varies across filesystems.

Action: one AtomicFile implementation with explicit durability semantics.

### 5.7 Direct `stat/find/readlink/chown/...` subprocesses — **platform hole, not merely an app bug**

Action: use `RxUnixSys`/RexxUtil immediately for the primitives they already cover, and put the remaining gaps behind `oorexx_posix`. Until the facade exists, keep current shell wrappers isolated; do not spread them further.

### 5.8 Direct SSH in business/application code — **layering smell**

Action: move behind remote-execution provider; placement and credentials remain external authorities.

---

## 6. Choices that are *not* inherently bad

The review should not mechanically replace every external program or custom codec.

- FFmpeg/libav integration in the camera and FD work is a specialist native capability. The right answer is Foreign Runtime/native bindings (which FD is already using), not pretending ooRexx stdlib replaces media codecs.
- Git is an external system with its own semantics. Invoking Git through the common Process API is reasonable; reimplementing Git is not.
- systemd, cloud CLIs and OS administration tools may remain external providers where no stable native API is intended, but calls belong behind provider interfaces.
- deterministic canonical formats used for signatures/digests may keep dedicated encoding rules, provided the format is centralised, versioned and tested.
- release artifacts may vendor dependencies for turn-key/offline delivery; that is different from maintaining duplicate authoritative sources.

---

## 7. Package-specific findings from the supplied top-level applications

### 7.1 ooRexx LLM Personal Assistant

**Good:**

- `LlmPaNativeOllama.cls` explicitly avoids curl and uses API Client/RxSock for loopback Ollama.
- JSON uses `.JSON` rather than hand-built JSON.
- Secret Broker is already present in external-provider configuration.

**Needs change:**

- `LlmPaExternalProviders.cls` instantiates `OpenAICompatCurlTransport`; replace with an API Client transport adapter.
- package release/stage code shells to `sha256sum`, `find`, `stat`, `df`, `zip` and `unzip`; move to CryptoFile, `oorexx_posix` and Archive APIs; prefer RxUnixSys/RexxUtil for the covered filesystem primitives.
- manual TSV stores in Core/Continuity/Workflow/Plan should converge on CSVStream or a shared durable-state codec.
- direct SSH knowledge should be consumed through a RemoteExecution provider.

### 7.2 Storage Evacuation

**Good:**

- transport is correctly separated from planning/state.
- before/after source metadata fencing is a strong design choice.
- destination verification is independent and generation-aware.
- symlink/hardlink/metadata fidelity is treated as a first-class concern rather than ignored.

**Needs platform extraction:**

- almost all `EvacPosixMetadataProbe`, extended metadata probing, tree inventory and metadata materialisation mechanics belong in `oorexx_posix`; the facade should delegate the covered operations to RxUnixSys/RexxUtil and reserve new native code for the identified gaps.
- `StoragePosixSha256Verifier` should use Crypto streaming.
- source quiescence needs an explicit authority/assurance model; stat-before/stat-after is evidence, not complete proof of application consistency.
- Storage Fabric is copied both under `src/` and `vendor/` and matches the current API bundle copy; keep one development authority and generate delivery copies.

### 7.3 QueueRexx

**Good:**

- Crypto already goes through the common Crypto/Foreign Runtime seam.
- QueueRexx serialization correctly uses `.JSON`, `.Yaml` and `.CSVStream`.
- process execution is at least abstracted behind `QueueCommandExecutor` and process probes rather than scattered entirely through business logic.

**Needs platform promotion:**

- promote the useful executor/process-probe concepts into `oorexx_process` and make QueueRexx a consumer.
- ownership/diagnostic `stat` and `chown` logic moves to `oorexx_posix`; its normal Unix provider delegates `chown` and ordinary stat fields to `RxUnixSys`.
- `/proc/<pid>/stat` start-cookie logic is useful Linux provider code for the common Process API, not QueueRexx-specific business logic.

### 7.4 FD Door Micro Motion

**Good:**

- TSV uses `.CSVStream` with tab delimiter—this is the model other packages should follow.
- FFmpeg access is through Foreign Runtime bridges rather than shelling to ffmpeg.
- checkpoint/migration output is partitioned and deterministic.

**Needs platform extraction:**

- file SHA-256 should use CryptoFile.
- migration-bundle `tar` creation/list/extraction should move to Archive API.
- repeated shell quoting disappears once archive/filesystem operations are native.

---

## 8. Source-layout and dependency specification

Every reusable component should have one development authority:

```text
oorexxapis/
  current/
    oorexx_process_v0.1/
    oorexx_posix_v0.1/
    oorexx_atomic_file_v0.1/           # or subpackage of posix fs
    oorexx_archive_v0.1/
    oorexx_file_snapshot_v0.1/
    oorexx_durable_state_v0.1/         # or evolved Journal Pointed State
    oorexx_package_resolver_v0.1/
    oorexx_remote_execution_v0.1/
```

Application repository:

```text
app/
  src/
  tests/
  integration.json        # component ids + compatibility ranges
  dependency.lock.json    # exact resolved ids/versions/digests for qualification
  vendor/                 # absent in development OR generated only
```

**Never:** copy a common `.cls` into `src/` and edit it there.

**Release assembler:** resolves dependencies, verifies digests, optionally vendors them, and emits a manifest saying exactly what was included.

---

## 9. Static architecture rules to enforce automatically

Add an estate linter to CI/source qualification. The linter does not need to understand all Rexx syntax; lexical rules are enough for the first pass.

### Forbidden by default outside platform/provider packages

- `ADDRESS SYSTEM` in ordinary domain classes.
- literal `curl`, `sha256sum`, `openssl dgst`, `stat -c`, `find ... -print`, `readlink`, `getfacl`, `getfattr`. For Unix filesystem work the first replacement choice is `RxUnixSys`/RexxUtil; new Foreign Runtime bindings require a documented capability gap.
- locally defined `shellQuote`/`quoteShell` functions.
- hand-built JSON object strings.
- manual TSV concatenation/splitting for general record I/O.
- source files under `vendor/` differing from lock-manifest digest.
- direct secret environment lookup in provider code when Secret Broker can own it.

### Required declaration for exceptions

Use a small machine-readable waiver, e.g.:

```json
{
  "rule": "external-command",
  "component": "git-provider",
  "executable": "git",
  "reason": "Git is the external system being integrated",
  "boundary": "provider",
  "expires": null
}
```

This prevents a linter from turning into dogma while still making architectural exceptions visible.

---

## 10. Migration order

### Phase A — stop creating new debt

1. Declare API Client, Crypto, Secret Broker, JSON/YAML/CSVStream authoritative.
2. Add static checks for new curl/sha256sum/manual-shell-quote usage.
3. Introduce dependency lock manifests and mark `vendor/` generated.

### Phase B — build the two missing foundations

1. `oorexx_process_v0.1`.
2. `oorexx_posix_v0.1` facade, reusing `RxUnixSys`/RexxUtil and adding only the missing fidelity primitives.
3. CryptoFile facade.
4. AtomicFile facade.

These remove the largest amount of duplicated infrastructure.

### Phase C — migrate highest-value consumers

1. AI provider curl transports -> API Client.
2. Storage Evacuation -> `oorexx_posix` + CryptoFile + snapshot authority; use `RxUnixSys` for covered chmod/chown/link/xattr/directory primitives and a coherent stat/lstat gap provider for exact fencing.
3. LLM PA release/stage -> Process/Filesystem/Archive/CryptoFile.
4. QueueRexx process and ownership primitives -> platform libraries.
5. CivicPort curl/digest/atomic writes -> API Client/CryptoFile/AtomicFile.

### Phase D — package/archive and durable state

1. libarchive-backed Archive package.
2. generalise Journal Pointed State into Durable State.
3. convert ad-hoc TSV journals where compatibility permits.
4. RemoteExecution provider abstraction.

---

## 11. Acceptance criteria for the platform cleanup

The platform refactor is successful when:

- no normal AI/provider HTTP path requires curl.
- no normal digest path requires `sha256sum`.
- ordinary domain code contains no shell quoting.
- POSIX metadata fidelity can be implemented without parsing `stat/find/readlink/getfacl/getfattr` output, with covered operations flowing through `RxUnixSys`/RexxUtil rather than duplicate libc bindings.
- TSV producers use CSVStream/shared codec unless a documented canonical format exception exists.
- a dependency is authored in one place and any vendored copy is generated from an exact digest lock.
- atomic state publication has one documented durability contract.
- backup/evacuation evidence distinguishes application-consistent snapshots from merely stable-window copies.
- process, filesystem, archive and HTTP implementations register their runtime capabilities/providers rather than being selected through executable-name assumptions.

---

## 12. Recommended ownership boundary

A useful rule for the estate is:

> **If three unrelated packages have to know the same shell command, escaping rule, filesystem syscall sequence, wire framing rule, temp-file publication sequence or process-lifecycle trick, it is platform code.**

Domain packages should mostly contain domain state, policy and orchestration. Platform packages should own operating-system mechanics, serialization mechanics, transport mechanics and durable publication mechanics.

That boundary will reduce both code volume and qualification burden: one POSIX metadata implementation can be heavily qualified once, rather than proving twenty shell wrappers separately.
