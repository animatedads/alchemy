# NewShell Native Providers v0.1-dev17 — Linux observation pump
Architecture: Tom Dyer. Coding and local qualification: ChatGPT.

## Current delivery (dev17)
Companion to **ooRexx Logging v0.8 additive subscription candidate**. The generic priority targets and subscription registry are removed from KernelLogging.cls and reside in LoggingSubscriptions.cls in that separate package. KernelLogBridge is a producer, not a separate logging service. The earlier bounded legacy KernelLogTarget remains for backwards compatibility. NewShell's existing JobBoard and policy remain authoritative. No daemon or raw proposal capability required.

- Register class `KernelLogBridge`, method `PUBLISH` or `PUBLISHPAM`, exact event points, priority and reserve with the generic registry. Bind the bridge. The PAM consumer accepts a generic priority target with generation-bound acknowledgement. New priority PAM consumer starts only on a reconciled empty lane; no historical action replay. Register `GAP` alongside PAM types and `KERNEL_LOG_GAP` for gap logging. Runtime locally invalidates same-runtime external audit collectors and disarms associated triggers when kernel stream evidence is incomplete, conservatively even if the gap cannot be delivered through logging. Source reader continues after EPIPE/ring wrap and header sequence discontinuity; unexpected read failure or invalid printk header still detaches. Gap history is not erased. Lane rearm is handler-owned; automatic handler-mediated rearm of runtime triggers is outstanding.
- Direct `/dev/kmsg` read-only. Requires suitable device permissions and CAP_SYSLOG where `kernel.dmesg_restrict=1`; do not grant unreviewed capabilities. EPIPE converted to typed GAP, not a terminal error. Does not clear the ring, register audit daemon or write kernel logs.
- `KernelAuditDecoder` accepts only kernel-facility canonical `audit: type=<number> audit(SEC.MS:SERIAL): pid=... uid=... auid=... ses=... msg='op=PAM:... res=...'` records; maps six reviewed types, strict field limits, tracks audit serial across recognized and unrecognized numeric audit records, reports jumps/reversal or `audit_lost=` as possible gaps. Repeated serial allowed. Only type, serial, epoch, PID, UID, AUID, session, operation, result and provenance retained. `acct`/`addr` and raw message excluded even with opted-in printk text. Other audit formats may be refused or produce conservative gaps; real target-host audit format must be confirmed. PAM publication via existing bridge and normalizer. Fixtures only, no real privilege or PAM manipulation. Direct audit netlink later: read-only multicast CAP_AUDIT_READ, never audit daemon registration.
- IPv4 TCP/UDP tables mandatory; absence of optional IPv6 table at open (ENOENT) returns IPV6=ABSENT and FAMILIES=1; existing unreadable/malformed tables fail closed. Present IPv6 returns PRESENT/2. Scope identity includes family coverage, so changes invalidate a prior baseline. Applies both namespace and process-reference scoped port snapshots. A native test uses actual private reader on IPv4-only synthetic proc tables; also tests existing unreadable tables and present optional tables. Actual IPv6-disabled host qualification still required (`REQUIRE_NO_IPV6=1`).

## Qualification and integration
465 PASS lines on clean native build and local regression with supplied r13196 and dev6 kit (444 prior + 21 new). New tests include 8 IPv4 fixture checks, 2 live family metadata checks, 11 kernel audit / priority PAM consumption checks. Generic logging package separately has 17 PASS lines. Existing mandatory live TCP tests remain skipped locally; live `/dev/kmsg` not exposed in this sandbox; live EPIPE and real audit records not yet qualified. Expected target run with REQUIRE_TCP_DIAG=1 adds four checks; REQUIRE_NO_IPV6=1 adds one check on actual IPv4-only host. No upstream v0.7 full regression, independent dev17 qualification, Git publication, durable logging-state journal or actual operational handler integration yet. Existing published dev14 baseline stays unchanged pending coordinated adoption.

Build: `REXX_INCLUDE=/path/to/include ./build.sh`. Test: `NEWSHELL_HOME=/path/to/newshell LOGGING_SUBSCRIPTIONS_HOME=/path/to/logging-v0.8-candidate REXX_INCLUDE=/path/to/include ./test.sh` with suitable Rexx PATH, library paths and json.cls. For release qualification set `REQUIRE_TCP_DIAG=1`; additionally set `REQUIRE_NO_IPV6=1` on actual IPv4-only kernel. See test-results.txt. No operational services were changed.

## Previous delivery history (superseded by current contract)
# NewShell native providers v0.1-dev14 — compound security evidence and TCP counter rates
Architecture: Tom Dyer. Coding and qualification: ChatGPT.
Additive contribution against newshell-kit-v0.1-dev6-jammy. No edits to upstream files.

## Current delivery (dev14): compound evidence, current process lineage, TCP counter rate probes
Architecture: Tom Dyer. Coding and local qualification: ChatGPT. Consolidated extension of dev13, not a new JobBoard or a request to change the published integration baseline. Trusted single-owner host use only; no new proposal-facing grants or operational mutation. All existing raw-provider/policy boundaries remain.

### Current process lineage
`NativeObservedProcess~parentEdge` reads the child and current parent through pinned `/proc` directories, validates child start ticks, rechecks PPID and parent start ticks and proc inode before returning. Fields include CHILD_IDENTITY, PID, START_TICKS, PPID, LINK_AVAILABLE, PARENT_IDENTITY and PARENT_START_TICKS (if present), BOOT_ID, MONO_MS, EPOCH_MS. `p~lineage(maxDepth=16)` returns OK, EDGES (array of current parent edges), TRUNCATED and SCOPE=CURRENT_PARENT_LINKS; max 32 edges. Revalidates every returned edge before returning; on error there is no partial lineage. A parent can have been adopted/reparented: this is **not** historical ancestry, an atomic whole-tree snapshot, or an ownership or signalling grant. Trusted local procfs/PID namespace required; a process can exit or reparent after observation. Identity is boot:pid:start-ticks within that scope, not cross-PID-namespace identity.

### TCP counter observation and registered rates
`POSIXProvider~tcpCounters(localPort)` uses read-only NETLINK_SOCK_DIAG / INET_DIAG_INFO TCP_INFO for established IPv4 and IPv6 sockets with that local port in the caller network namespace. Returns OK/ERRNO/ERROR; on success SOCKETS rows COOKIE, ACKED_BYTES, RECEIVED_BYTES; scope ESTABLISHED_TCP_LOCAL_PORT, IDENTITY, BOOT_ID, NET_NAMESPACE, PORT, MONO_MS, EPOCH_MS. No packet payload, remote addresses or process ownership claims. Requires kernel socket diagnostic support and visible namespace; failures/interrupted dumps/truncation/unsupported TCP_INFO layout return no partial rows. Limits per family: 500ms deadline, 4MiB dump, 8192 socket records; at most 1024 matching sockets total. Not an atomic kernel-wide sample. These are TCP payload counters, not wire octets, packet rates, retransmission volume or UDP accounting. Does not observe closed/short-lived connections that disappear between samples, nor a complete per-port traffic ledger.

```
probe = .SecurityTcpRateProbe~new(443, 5000)
metric = .SecurityMetric~new('received', probe, 'TCP_RECEIVED_BPS', 10485760, 5242880, 2097152, 5000)
sampler~register(metric)
metric~history~~table
```
`SecurityTcpRateProbe~snapshot` (or `~evaluate` of a trusted raw snapshot for fixtures) compares the **same set of socket cookies** at consecutive samples, with the same scope identity and valid monotonic elapsed time. Returns integer bytes/second `TCP_ACKED_BPS` and `TCP_RECEIVED_BPS` (uppercase B = bytes), corresponding delta byte counts, ELAPSED_MS, SOCKET_COUNT and identity fields. First sample, counter decrease, duplicate cookie, missing provider, changed membership or scope, or invalid elapsed interval = explicit unavailable/gap; no guessed zero. A stable sampled set is not proof of no unseen socket churn. Namespace-level rates cannot automatically implicate an individual process. A later per-process TCP rate provider would need separate socket-reference identity and coverage checks. The existing dev13 queue and connection metrics remain distinct.

### Compound incident review
```
-- Existing trusted host: rt, registered sampler, registered PAM source,
-- and prebuilt authorised reviewPlan. Sampled process identity is known.
snap = p~securitySnapshot
rule = .SecurityIncidentCorrelation~new('incident', 'pam', 'metrics', 'priv', 'rss', 'port', snap['BOOT_ID'], snap['AUID'], snap['AUDIT_SESSION'], snap['IDENTITY'], 30000)
rt~attachCorrelation('incident-source', rule)
rt~arm('incident-review', 'incident-source', 'INCIDENT_MATCH', reviewPlan, 'incident')
-- Existing host event loop drives rt~pump. The runtime also collects on ingestAudit.
```
Requires known AUID and audit session (UNSET/UNKNOWN refused), fixed local boot/process identity, distinct exact registered audit and metric sources and three exact metric subjects. One-shot match requires PAM_AUTH_SUCCESS or PAM_SESSION_OPEN for the same boot/AUID/session, observed nonroot->root EUID transition and RSS rise for the exact same process identity and known session, plus a process-reference-scoped port rise/high for that process identity. PAM's historical PID is not used as proof of process attribution. The auth observation must precede the other three in event time and all four must fit the configured 1..300000ms window. Journal consumption begins at bind cursor, never replays older journal records into actions. Recent delayed source records can join, if fresh and otherwise matched; samples older than the window are ignored, future timestamps beyond 1s and detected epoch-vs-monotonic discontinuity beyond 2s quarantine. Uses the newest observed candidate per kind, not exhaustive matching or a forensic causal proof; interleaving, missed observations and newer evidence can prevent matches. Single owner activity, one match then detach. Whole new journal page checked for relevant source/sample gaps first; retention loss, >1024 pending records, malformed evidence or invalidated source disarm rather than dispatch. A quarantined source requires a fresh correlation object and explicit reconciliation. `INCIDENT_MATCH` includes four journal event IDs, span, process/session identity, AUTH_LINK=SESSION_ONLY and CLASSIFICATION=REVIEW_REQUIRED. Dispatch uses existing plan template, policy, quotas and causal receipts; no executable arguments drawn from evidence. Journal remains bounded and memory-only. No actual login, credential change, process memory contents, traffic contents or system policy mutation performed.

### Qualification and remaining gates
Local clean native rebuild (`g++ -Werror`, supplied ooRexx 5.3.0 r13196 and dev6 NewShell kit), `test.sh`: **388 PASS lines** (349 retained + 39 new). Eight named suites, registry checks and marker fixture. Actual current parent chain checked and revalidated. Actual dev13 child-memory and loopback queue tests retained. Compound rule tested with synthetic authenticated/privilege/metric observations delivered via the native timer and trusted PAM adapter into an actual governed JobBoard review, including session/process mismatch, stale input, time window, source/retention gaps and one-shot behavior. Counter arithmetic, reset, membership, duplicate, elapsed and registered-rate transitions tested using fixtures. **Live SOCK_DIAG dump and loopback TCP_INFO counter test are NOT qualified locally**: this kernel returns ENOENT for IPv4 and IPv6 diagnostic dumps. The log records both skipped live checks and confirms no partial rows were returned. Run `REQUIRE_TCP_DIAG=1 ./test.sh` on a host with TCP socket diagnostics available (plus the normal NEWSHELL_HOME/REXX_PATH/LD_LIBRARY_PATH settings). This requires the four live loopback transfer assertions as well as the 388 ordinary checks; do not claim success if it skips or fails. No independent dev14 Jammy/Autobuild/ED209 qualification, Git publication, direct kernel audit subscription, historical exec/setuid audit linkage, actual per-process traffic byte attribution, durable journal or high-load qualification. No new operational permissions. The existing integration baseline remains until Claude coordinates adoption.

## Previous delivery (dev13): security observation and registered changes
Architecture: Tom Dyer. Coding and qualification: ChatGPT. This is a consolidated extension of the dev12 reference runtime, not a replacement for the published dev10 integration baseline. Native providers are read-only for these observations; no changes to PAM, auditd, security policy, or target-machine configuration. No new proposal-facing grants. AtomicFile remains the sole publication contract.

### Process and network evidence
- `NativeObservedProcess~securitySnapshot` returns OK/ERRNO/ERROR and PID, PPID, START_TICKS, BOOT_ID, IDENTITY (boot:pid:start-ticks, local trusted procfs scope), UID, EUID, AUID, AUDIT_SESSION, NET_NAMESPACE, MONO_MS, EPOCH_MS, MEMORY_AVAILABLE, and available RSS_KIB, PEAK_RSS_KIB, VIRTUAL_KIB, ANON_KIB, FILE_KIB, SHMEM_KIB, SWAP_KIB. No reads of the process's memory contents. Audit login/session identifiers are decimal strings, UNSET for the kernel sentinel or UNKNOWN if unavailable. Never substitute UID for AUID. The provider observes the process leader; credentials can change during the snapshot; these are live observations, not atomic kernel snapshots. Clock readings label completion of observation; epoch clock may step. Pin /proc/PID and verify start time before and after. Trusted procfs and consistent PID/user namespace are required; do not treat boot:pid:start as globally unique across differently mounted PID namespaces. Host/MU identity must be supplied by the owning runtime when exporting remotely.
- `POSIXProvider~portSnapshot(port, protocol='tcp')` returns a network-namespace aggregate over IPv4 and IPv6 local-port rows in `/proc/PID/net/{tcp,tcp6,udp,udp6}` (caller namespace), including SOCKET_COUNT, ESTABLISHED_COUNT, LISTENER_COUNT, RX_QUEUE, TX_QUEUE, FAMILIES, MONO_MS, EPOCH_MS, BOOT_ID, NET_NAMESPACE, PROTOCOL, PORT, IDENTITY and SCOPE. TCP-only state counts are zero for UDP (not evidence of UDP connection state); queue fields are kernel queue occupancy, not cumulative bytes transferred, not bit/s, not packet contents. Includes TCP non-established states. No packet capture, promiscuous mode, connection intervention, or global port ownership claim. Each proc file is bounded to 256 KiB; oversized tables or absent required IPv6 table fail closed rather than yielding misleading partial sums. Live table scans can differ between families. 
- `NativeObservedProcess~portSnapshot(port, protocol='tcp')` filters rows by socket inode references read (not followed) from that process's `/proc/PID/fd`. At most 4096 descriptor entries per pass; socket-reference set and start ticks checked again after scan; namespace checked before and after. Returns PROCESS_IDENTITY, PID, START_TICKS, SCOPE=PROCESS_REFERENCES as well. Shared sockets can belong to multiple holders; not exclusive attribution or proof that the holder sent particular bytes. Only sockets present in the target's current namespace are covered. Identical reference sets do not guarantee absence of intervening churn; no atomic snapshot. Permission failures and concurrent churn can invalidate observations.

### Registered changes and bounded history
```
p = .ProcessProvider~new~observe(1234)
sampler = .SecuritySampler~new
rss = .SecurityMetric~new('rss', .SecurityProcessProbe~new(p), 'RSS_KIB', 262144, 196608, 32768, 5000)
sampler~register(rss)
port = .SecurityMetric~new('port443', .SecurityProcessPortProbe~new(p,443), 'SOCKET_COUNT', 50, 30, 10, 5000)
sampler~register(port)
sampler~register(.SecurityIdentityMetric~new('identity', .SecurityProcessProbe~new(p)))
t = .POSIXProvider~new~timer(1000,1000)['TIMER']
rt~attachSampler('metrics',t,sampler)
rt~arm('memory-review','metrics','METRIC_RISE',reviewPlan,'rss')
rt~arm('port-review','metrics','METRIC_HIGH',reviewPlan,'port443')
rt~arm('identity-review','metrics','IDENTITY_CHANGE',reviewPlan,'identity')
-- trusted host drives rt~pump; reviewPlan is prebuilt by the trusted owner
rss~history~~table
rss~history~~json
say rss~historyDropped
```
`SecurityMetric(name, probe, metric, high, low, delta, maxGapMs=10000)` uses signed absolute change per adjacent valid sample, rising/falling threshold crossings and hysteresis; no adaptive statistical baseline or rate threshold. METRIC_RISE/FALL, METRIC_HIGH/RECOVERED, METRIC_BASELINE and SAMPLE_GAP have structured scalar/JSON detail; elapsed milliseconds permit rate calculation outside the detector. Initial high baseline is recorded as ABOVE_HIGH, not a crossing. Missing data, changed identity, excessive/missed intervals reset the baseline; no fabricated zero or cross-gap delta. Polling is timer-driven, not an instantaneous kernel memory change notification. Peak RSS can reveal some otherwise missed transient peaks. SecurityIdentityMetric compares UID/EUID/AUID/audit session/net namespace within the observed process identity, emits IDENTITY_CHANGE with old/new known values and marks unavailable fields as gaps. Does not infer a breach from a change. No per-thread identity or capability-change watch yet (credentials API remains available). Identity watches are sampled and do not capture all brief transitions. SecuritySampler supports 32 registered metrics; each metric keeps the latest 256 immutable sample rows (historyDropped exposes eviction). `history` returns ShellCollection for common table/JSON output. For identity metrics use journal observations rather than numeric history. Each registered metric reads its probe separately; batching/deduplicating probes and performance optimisation are future work. Timers and all raw objects remain trusted owner-only, and must be explicitly closed.

### PAM events through the same runtime
```
root = .POSIXProvider~new~openRoot('/var/log/audit')['ROOT']
boot = .ProcessProvider~new~observe(SysQueryProcess('PID'))~securitySnapshot['BOOT_ID']
adapter = .PamAuditAdapter~new(boot)
tail = .PamAuditLogTail~new(root,'audit.log',adapter)
rt~attachAuditLog('pam',tail)
rt~arm('pam-review','pam','PAM_AUTH_FAILURE',reviewPlan)
-- pump existing event runtime; close/detach tail and root on shutdown
```
Optional adapter for an existing, authorised, trusted auditd append-only text log. Uses inotify on the containing pinned root and a pinned reader; starts at complete record boundary at EOF (no historical execution). Handles append in bounded 64 KiB / 256 accepted records, 16 KiB line length with partial-line buffer. Accepts strict canonical ordered auditd text lines with type, audit(epoch.ms:serial), pid, uid, auid, ses and quoted op=PAM:... terminal res=success/failed; not a general auparse replacement. Skips nonmatching text, quarantines malformed candidate PAM records and observed audit-daemon lifecycle records. Does not parse arbitrary journald/syslog messages. No raw acct/addr/exe/payload emitted. Audit ID scoped by boot/epoch/serial/type, dedup last 1024, one-shot action rules. Authentication, account, session open/close, credential acquisition/disposal, failed operations normalized. Rotation, deletion, metadata changes, overflow, truncation, replacement or excessive backlog cause AUDIT_GAP and disarm the source; manually reconcile, then reattach. Append-only trusted log assumption: cannot detect every in-place edit, truncation/regrowth between reads, audit event loss upstream, noncanonical PAM formatting or host compromise. Do not expose log access or ingestion to an LLM. A trusted external collector may alternatively call `rt~attachAudit('pam',adapter)` and `rt~ingestAudit('pam',record)` using validated structured fields BOOT_ID, ORIGIN=PAM, TYPE, SERIAL, EPOCH_MS, PID, UID, AUID, SESSION, RESULT. TYPE=GAP disarms. No audit configuration, CAP_AUDIT_READ multicast subscription, libauparse adapter, direct PAM hook or automatic log rotation continuity implemented. Live real PAM/auditd qualification needed; fixture records only in local test. Audit event provenance rests with the trusted collector; never treat parsed text alone as authentication proof.

### Evidence and response
`SecurityEvidenceView~processTrail(identity,after=0,limit=128)` filters the bounded journal page for exact observed identity or process socket reference. `~sessionTrail(boot,auid,session,after=0,limit=128)` filters on known audit login/session (reject UNKNOWN/UNSET), not simply a numerical PID. Retains original page NEXT/LATEST/GAP for paging. PAM event PROCESS_LINK=UNVERIFIED: a historical PAM PID is not automatically assigned to a later live process; the journal preserves event time and observed process start identity separately. Session-level association is not causation. Cross-source compound correlation, process parent lineage, audit exec/setuid syscall events, live network per-port transfer rates, long-term persistence, time-window joining and authenticated remote source identity remain future work. Registered rules are existing one-shot, exact event kind and metric subject; actions use preconfigured plan templates and existing JobBoard policy under owner principal. No automatic blocking or killing based on spikes. Runtime is reference integration, single trusted owner activity, not production replacement JobBoard. Journal and series in RAM; replay never executes actions.

### Qualification
Full clean native rebuild with g++ -Werror, supplied ooRexx 5.3.0 r13196 and NewShell dev6 kit: 349 PASS lines, 293 existing + 56 security-observation checks; all seven suites and marker fixture passed. Real disposable C++ child allocated/touched 32 MiB, opened an ephemeral IPv4 loopback listener, established a local connection and queued 4096 bytes. Measured RSS 1740 -> 34524 KiB, attributed local-port socket references 0 -> 2. Unrelated interpreter not attributed those sockets. Native timer -> two review plans, trusted audit-record injection and actual inotify append of fixture text -> two more review plans, all four pass existing policy. Log rotation disarms the watcher. Also tests hysteresis, gaps, stale IDs, dedup, history retention/table/JSON, evidence query and policy receipts. Actual PAM authentication and elevated privilege transitions not generated (fixture only for PAM and identity transition). No Jammy or ED209 independent dev13 run, Git publication, long-run load or large-table performance qualification. No new grants or upstream changes. Earlier dev12 remains the historical reference and dev10 remains the published baseline unless owner coordinates adoption. One consolidated review candidate.

## Historical delivery (dev12): complete vertical event-to-job qualification
Dev10 is now the published NewShell integration baseline (9f1a714c), independently qualified 214/214 on Ubuntu 22.04 and the autobuild host (REQ-00005787). Dev11 independently passed 249/249 on Jammy, with six further 35/35 persistent-mux runs (REQ-00005803). This delivery includes dev11 unchanged at the native layer and a complete optional trusted ooRexx event runtime. It is a single consolidated review candidate, not a request to move the existing baseline without agreement. The runtime is a vertical integration reference, not a second production JobBoard: adapt its semantics to Claude's existing host/event-loop class. No upstream files or default policy changes. AtomicFile remains the only platform publication contract.

### Interfaces and usage
`ShellEventRuntime.cls` requires existing NewShell ShellJobs.cls and the bundled POSIXProvider.cls. Create the runtime in a trusted host activity with `rt = .ShellEventRuntime~new(sessionId, owner, journalCapacity=4096, maxDispatch=128)`. In actual Rexx positional arguments, pass just the session ID and owner for defaults. Session IDs, rule names and source labels are 1..128 characters, start with an ASCII letter and contain only letters, digits, `_`, `.` and `-`. The caller must choose a new unique session ID each time; it is not a durable cross-boot ID. Owner is the existing trusted job owner with `principal`, `kind`, `jobFinished`; principal must be llm, codex or console. Principal is captured on construction; the owner must retain the same principal for all jobs. This reference creates its own existing JobBoard instance with that owner; production should attach to the owning host's board instead of running two boards.

```rexx
provider = .POSIXProvider~new
root = provider~openRoot('/path/to/authorised/workspace')['ROOT']
watch = root~watch('.')['WATCH']
rt = .ShellEventRuntime~new('unique-session-id', owner)
registration = rt~attach('incoming', watch)['REGISTRATION']
plan = rt~board~plan('review')
step = plan~step('inspect')
step~does(workspace, 'run', .Array~of('echo', 'Received input'))
step~passIf('exitIs', 0)
rule = rt~arm('review-input', 'incoming', 'FS_CLOSE_WRITE', plan, 'x:'||'input.bin'~c2x)
do i = 1 to 20
    result = rt~pump(1000)
    if rule~state == 'FIRED' then leave
end
rt~collectJobs
say rt~journal~exportPage(0, 128)
rt~close
watch~close
root~close
```

The example assumes `owner` and `workspace` are existing trusted host objects and a suitably authorised policy. Always check native OK results and close resources on error as well as success. `attach(label,source)` retains the wrapper, registers with the persistent mux and journals attachment; caller owns source/root lifetime. `detach(registration)` unregisters, journals and disarms all still-armed rules for that label. Reusing a label cannot rearm the old rules. `close` shuts down the mux and disarms rules, but does not close the source wrappers, cancel active jobs or imply that jobs settled; `collectJobs` may still be called afterwards. One trusted owner activity invokes these methods; no concurrent host dispatch guarantee. Native mux concurrency is unchanged.

`arm(name,label,kind,template,subject='')` is trusted configuration, not proposal authority. Supported trigger predicates are TIMER, PROCESS_EXIT, FS_CLOSE_WRITE and FS_MOVED_TO, with matching native source type. Filesystem predicates optionally match a case-sensitive byte identity `x:HEX` (uppercase hex); empty subject matches any non-directory entry for that kind. A native notification does not prove a regular file still exists, is readable, is safe, or is complete. The triggered plan must revalidate the relevant resource as needed. Event content never supplies methods, source code, commands or arguments to the plan. A structural copy of plan steps is taken on arm; target references and objects in arguments/checks remain live references, not deeply frozen. Template notification and origin settings are not copied. Rules are one-shot, max 128 retained, and are consumed on dispatch attempt or disarmed on source loss/limit. `disarm(name)` removes the rule. Max lifetime dispatch attempts 1..128, default 128; new work beyond the limit produces DISPATCH_LIMIT, not a silent retry. Existing JobBoard retains submitted jobs; this reference is bounded by the dispatch quota, not a perpetual scheduler.

`pump(ms)` uses the persistent mux (0..5000 ms). It drains timers and records the expiration count, confirms process exit once and detaches that source (existing runner still owns reaping), or drains at most 128 filesystem records per ready watch per pump. File byte names are losslessly hex-encoded. Close-write/move-to directory events are recorded separately, never matched by file rules. A watch batch reporting RESCAN_REQUIRED is discarded, its source detached, still-armed rules disarmed; a fresh authorised watch and reconciliation are required before rearming. This does not retroactively invalidate actions taken before overflow/ancestor movement became observable. Native readiness remains a hint. No filesystem writes or signalling from the runtime itself.

### Causal receipts and policy
A matched rule creates a fresh Plan through the runtime's existing JobBoard. Plan steps are copied, not generated from kernel data. The submit call is made by a Routine under `ShellSecurityManager` with the captured principal. Existing Plan execution applies the normal per-action manager with the trusted owner's principal. A job name includes session:sequence:rule; journal entries DISPATCH_ATTEMPT, SUBMITTED/DENIED/DISPATCH_UNKNOWN, and JOB_SETTLED link back to the triggering observation through `cause`. SUBMITTED is not successful completion. Unknown dispatch is not retried; the board might already have received the job. JOB_SETTLED uses actual `Plan~settled` and `Plan~state`; active jobs are checked at each pump or explicit collectJobs, not yet notified by a completion eventfd. No exactly-once across restart, cancellation or durable audit guarantee. The full decision/step details remain on the existing Plan object, not duplicated in the observation journal. Keep this class, board getter, journal and native provider out of proposal grants. No changes to ProposalCheck or policy.

### Bounded journal and replay
`ShellEventRecord` inherits ShellObject; fields session, sequence, source, kind, subject, count, cause, detail, observed. `identity` is session:sequence. Time is local observation time, not a kernel timestamp or globally ordered clock. Count is bounded to unsigned 64-bit. `ShellEventJournal~replay(after=0,limit=128)` gives SESSION, FIRST, LATEST, NEXT, GAP and EVENTS; 1..1024 records per page, `after` is last consumed sequence, and GAP explicitly indicates evicted history. Capacity 1..65536 entries; bounded scalar field sizes. `exportPage` exports the page as JSON through the ooRexx json.cls. Reading/replaying/exporting never runs actions. The journal is RAM-only, and export is a string: persistence, crash/restart reconciliation, append integrity, durable trigger state and authenticated audit receipts remain future work. Use AtomicFile for eventual checkpoint publication; do not invent another write path. This is not a complete kernel audit history (inotify coalesces and can lose events).

### Qualification and scope
Fresh native build with supplied r13196 and dev6 kit, complete unchanged 249 checks plus 44 new event-runtime checks = 293 PASS. The new suite verifies actual inotify -> plan -> Workspace echo -> PASSED, timer -> protected action refusal -> FAILED, actual disposable child exit -> plan -> PASSED, board submission denial -> no job, causal links, structural template copy, one-shot non-repeat, replay gap/export, source invalidation/closure, stale-label refusal, lifetime quota and shutdown. Tests use temporary policies and workspace only. No actual dev7 upstream integration or dev12 Jammy/ED209 qualification. No LLM API calls. JobBoard policy and native event semantics are locally exercised; external writer/mount attacks, durable restart, performance and full concurrency qualification remain outside this delivery. Initial development tests caught Rexx RESULT variable reuse, Directory iteration yielding keys, and fixture syntax/import errors; corrected and complete suite rerun. Existing native code and previous test sources unchanged. See test-results.txt for actual full run. The `ShellEventRuntime` layer is an integration candidate to review alongside the existing host class; do not install another long-running controller by default.

## Historical release (dev11)
Dev7 remains the published integration baseline; dev10 remains the next candidate pending independent qualification. Dev11 is an optional subsequent extension, not a request to change that candidate. Filesystem operations remain read-only and AtomicFile is the sole publication authority.

`r = provider~openEventMux` returns OK/ERRNO/ERROR and MUX on success. `m~register(source)` accepts an existing POSIXWatch, POSIXProcessHandle or POSIXTimer, returning REGISTRATION (monotonically increasing per-mux unsigned ID; numeric digits 20 if performing arithmetic). `m~unregister(id)` removes the registration without closing the source. `m~wait(milliseconds=0)` accepts 0..5000 ms, including an empty registration set. Returns EVENTS (rows REGISTRATION, KIND, READY, CLOSED, ERROR_EVENT, HANGUP), WOKEN (explicit wake requested), CHANGED (registration change during wait), CLOSED (mux closed during wait), TIMED_OUT. A registered closed source produces a one-time CLOSED row and is removed; explicit unregister cancels that notification. IDs are never reused within a mux. `m~wake` posts a coalesced wake request through eventfd, even if no waiter is currently present. `m~close` releases registrations, wakes an active waiter and invalidates subsequent calls. UNINIT is fallback only. The original dev10 snapshot `eventMux~wait(sources,ms)` is unchanged.

One persistent epoll descriptor and one eventfd per mux, with one duplicate descriptor per live registration; no rebuilding registrations on each wait. Up to 32 muxes and 128 registrations per mux; registry failures distinguished from OS exhaustion. Closing a source (including root closing its watches) immediately removes and closes its duplicated descriptors in each mux, leaving bounded closure tombstones until collected or explicitly removed. Registration changes during a wait wake it. Native state protected by registry mutex; only one active waiter per mux (EBUSY otherwise). Wait releases registry mutex and Rexx object guard, pins mux lifetime, and revalidates registrations on return. Keep source objects reachable and explicitly close them; registering does not retain the Rexx wrapper or own source lifetime. Serialize source drains; multiple muxes on the same source are not independent consumers. Notifications coalesce; they are not a durable journal or proof of event ordering. Each wait still scans the bounded registration table for buffered inotify events and sticky invalidation, so no O(ready-only) performance claim. Readiness is level triggered, not an authorization. Remove terminal process or invalidated filesystem sources to avoid a busy loop. No indefinite native wait, callbacks, persistent scheduling, automatic cancellation of in-flight source I/O, or policy grants.

Qualification: complete local suite 249 PASS (214 previous + 35 new) using supplied r13196/dev6; three additional runs of the 35-check persistent suite all passed. Tests include concurrent Rexx Message activities for wake, second waiter refusal, register/unregister, source closure and mux closure; actual disposable child exit/reap; buffered watch events; closure tombstones; registry exhaustion/recovery; explicit uninit. Thread scheduling tests use short sleep to allow a waiter to enter native wait; not an exhaustive race/stress proof. No throughput/latency benchmark, independent dev11 Jammy or ED209 run, upstream integration, publication, or durable journal. Build uses source-only archive, not a precompiled library.

## Historical release (dev10)
Dev7 remains the published baseline (6b025378). Claude independently confirmed dev9 on Ubuntu 22.04: 186 PASS (REQ-00005777). Dev10 is the next integration candidate, subject to independent qualification and coordinated adoption. All filesystem operations remain read-only; AtomicFile remains the sole publication authority. No new proposal grants.

### Timers and mixed event sources
`provider~timer(first, interval=0)` returns OK/ERRNO/ERROR and TIMER on success. Both parameters are milliseconds; first 1..86400000, interval 0..86400000 (zero means one-shot). Linux timerfd uses CLOCK_MONOTONIC, nonblocking and close-on-exec. Not wall-clock scheduling, durable scheduling, or suspend-aware alarm delivery. `timer~drain` returns EXPIRATIONS (unsigned 64-bit count, zero if none), not a callback or one row per tick. Periodic timers accumulate missed expirations. Use Rexx numeric digits 20 when doing arithmetic on counts. `timer~close` disarms/releases the descriptor; UNINIT is a nondeterministic fallback. Maximum 128 timers; TIMER_REGISTRY_FULL is separate from OS descriptor exhaustion. Re-arm by replacing the timer; no reset operation in this version.

`mux = provider~eventMux`; `r = mux~wait(.Array~of(watch, processHandle, timer), milliseconds=0)` accepts a dense array of 1..128 trusted source objects, timeout 0..5000 ms. Duplicate nonempty source tokens are refused. Returns OK/ERRNO/ERROR, EVENTS (array in input-index order, not chronological order), TIMED_OUT. Rows: INDEX (1-based source index), KIND (FILESYSTEM/PROCESS/TIMER, or UNKNOWN for already closed source), READY, CLOSED, ERROR_EVENT, HANGUP. Closed sources are reported immediately, and must be removed by the consumer. Treat error/hangup flags as requiring source-specific handling. Ready is a hint, not the event itself: drain a watch with nextBatch, drain a timer for count, or confirm a process exit with waitExit. Process exit is level-triggered until the source is removed; the original runner remains the child-reaping authority. Buffered inotify records and sticky rescan state count as readiness even when its kernel queue is empty. Overflow/invalidation reconciliation requirements are unchanged; remove/replace a sticky source after reconciliation to avoid a busy loop.

Implementation creates an epoll instance for each bounded wait, registers duplicate descriptors from one registry snapshot, waits without holding the registry mutex, revalidates source tokens under the mutex, and releases all duplicates and the epoll instance at return. No long-lived native epoll registration table, native event thread, callbacks, or persistent event journal yet. A close during a wait may not wake the waiter immediately; the closed state is checked before returning. Another consumer could drain a ready source; callers must serialize consumption and keep objects reachable. No guaranteed cancellation or transactional observation across sources. Raw eventToken is an internal bearer token, never a proposal-facing capability. The trusted native routines do not interpret LLM text or grant authority. No event is an authorisation to perform a mutation.

Qualification: 186 previous local checks plus 28 new event/timer checks, total 214 PASS using the supplied r13196 interpreter and NewShell dev6 kit. Tests include one-shot and accumulated periodic expiry, mixed readiness across three source types, actual disposable child termination/reap, buffered and invalidated watch readiness, closed sources, duplicate-source rejection, bounded waits, and timer registry exhaustion/recovery. No concurrent close/wait stress or performance benchmark, no independent dev10 Jammy/ED209 run, no integrated policy or event-bus qualification. Initial test invocation lacked REXX_PATH for json.cls; corrected environment and reran complete suite. Source-only distribution.

## Historical release (dev9)
Dev7 remains the fixed integration point. Claude reported independent 134/134 qualification on Ubuntu 22.04 and the r13196 autobuild host, and publication at commit 6b025378 (REQ-00005761). This release is a subsequent optional extension of dev8, with all filesystem operations read-only; AtomicFile remains the publication authority.

`root~watch(relative='.')` returns OK/ERRNO/ERROR and WATCH. Resolves a directory under the pinned root with openat2, rejects symlinks and escapes, and registers a single non-recursive inotify watch through the trusted `/proc/self/fd` interface. The watch follows the directory inode, not the name. A watched directory's own move/delete/unmount or IN_IGNORED sets sticky INVALIDATED and RESCAN_REQUIRED. Ancestor moves and mount replacement need separate root/path reconciliation; no claim of ongoing pathname containment. Trusted local procfs and inotify are required. Do not expose raw handles, routines or arbitrary watch paths to proposals.

`watch~nextBatch(limit=128)` is nonblocking, accepts 1..1024, and returns EVENTS (array of rows NAME, MASK, COOKIE, IS_DIRECTORY, KINDS), DRAINED (queue observed empty), OVERFLOW, INVALIDATED and RESCAN_REQUIRED. KINDS contains symbolic CREATE, DELETE, MOVED_FROM, MOVED_TO, CLOSE_WRITE, ATTRIB, MODIFY, DELETE_SELF, MOVE_SELF, UNMOUNT, IGNORED or OVERFLOW. NAME is raw filesystem bytes; may be empty for self/overflow events. Rename cookies correlate events when both sides are visible; no guarantee of paired events. A fixed 4096-byte native buffer preserves events across bounded batches; no unbounded userspace queue. Kernel coalescing and overflow are possible. On reading IN_Q_OVERFLOW, OVERFLOW and RESCAN_REQUIRED remain set for the lifetime of that watch. Discard invalidated batches for path-scoped policy, close and re-establish authorised root/watch, and reconcile with a fresh enumeration; the event stream is not a complete audit record. Overflow is only known once its marker has been drained. Events after directory movement may refer to the original inode outside its old pathname; no automatic re-arm. Consumers should serialize drain operations, use readiness only as a hint, and never treat notification as authority to mutate.

`watch~waitReady(milliseconds=0)` waits using poll with a monotonic EINTR deadline (0..5000 ms), and returns READY, TIMED_OUT and sticky status flags. Buffered events and sticky rescan state also count as ready. Readiness can be stale if another caller drains events. `watch~close` releases native state; UNINIT is a backstop. Root closure invalidates associated watches; in-flight waits may not return until their deadline, then report closed handle. Up to 128 watches per process, WATCH_REGISTRY_FULL separate from kernel resource exhaustion; kernel per-user limits may be lower. No recursive watch, epoll multiplexing, kernel audit, event persistence, or policy-facing watch integration yet.

Local qualification: 159 prior checks plus 27 watch checks = 186 PASS on uploaded ooRexx r13196 and dev6 kit. Actual kernel queue overflow was induced with the local 16384-event queue; overflow tests skip explicitly when kernel queue size is outside the test budget (1..65536). Test fixture writes, moves and deletes only in its temporary directory; native provider performs no writes. Initial fixture directory was created before an existing exact-entry-count test; moved fixture creation after the old suites, which now pass unchanged. Watch registry exhaustion, concurrent close/wait, adversarial mount/path races, ED209 and independent Jammy runs not yet qualified. Source-only package, no new policy grants or upstream merge.

## Historical release (dev8)
Dev7 remains the fixed integration point for Claude. Dev8 is an additive candidate, not an instruction to change that baseline. Filesystem operations remain read-only. The historical sections below describe earlier versions; the pidfd operations in this section are the sole new mutation capability.

`ProcessProvider~openProcessHandle(observation)` accepts a trusted NativeObservedProcess observation, and returns OK/ERRNO/ERROR, PID, START_TICKS and PROCESS_HANDLE on success. Uses Linux pidfd_open, checks the expected start ticks before and after acquisition, checks the pidfd fdinfo PID, and compares the pinned proc directory device/inode with a fresh lookup. Requires a trusted procfs in the caller PID namespace, permitted pidfd syscalls and openat2; returns an error if unavailable. PID+start-ticks is a local observation, not a globally unique or durable identity (tick collisions and prior boot observations are not covered). No fallback to numeric PID signalling.

`h~waitExit(milliseconds=0)` uses poll on the retained pidfd, with 0..5000 ms bound and monotonic deadline on EINTR. OK=1, EXITED and TIMED_OUT distinguish exit, live poll and timeout. No exit code is inferred; child reaping remains the existing ProcessNativeProvider responsibility. `h~signal(number)` accepts 0, SIGHUP, SIGINT, SIGTERM and SIGKILL only, with kernel permission checks. ACCEPTED means the syscall succeeded, not that the process has exited. No process group signalling via this handle. `h~close` releases it; UNINIT is a nondeterministic backstop. Maximum 128 process handles, PROCESS_REGISTRY_FULL distinct from EMFILE. Handles are random bearer tokens. A duplicated descriptor in an in-flight operation can survive close. Do not expose the raw handle, constructor, native routines, or provider to proposals; authorisation at the resource method is still required. No policy-facing mutation integration or change to the existing PID-based signal API. No assertion of PID reuse stress qualification, namespace mismatch adversarial tests, cross-node identity, or ED209/Jammy qualification.

Local qualification: 134 previous checks plus 25 pidfd checks = 159 total. The only nonzero signal during testing targeted a disposable sleep child started by the suite. Initial child fixture used unsupported detached CAPTURE; corrected to DISCARD. Child exit, reaping, stale ticks, closed/guessed handles, registry exhaustion and recovery tested. No proof against adversarial procfs mounts.

## Historical integration point (dev7)
This source release deliberately branches from independently qualified provider dev5, not experimental write-provider dev6. All filesystem capabilities in this release are read-only. The experimental createFile/replaceFile methods and native entry points are absent. Existing ProcessNativeProvider execution/reap/signal capabilities are unchanged; no new proposal authority is granted. The approved platform publication path remains `oorexx_atomic_file` (API `oorexx.atomic-file/0.1`). Do not integrate the experimental dev6 publication API or reinterpret its tests as AtomicFile qualification.

`POSIXRoot~capacity(relative='.')` returns the same block/fragment/inode fields as `POSIXProvider~capacity`, but resolves beneath the retained root using openat2. It pins the root during the operation, rejects invalid paths and symlinks, and fails on closed handles. An in-flight operation can complete after root closure. Mount crossings remain permitted; no I/O deadline. Capacity is a live observation. Calculate available bytes from AVAILABLE_BLOCKS * FRAGMENT_BYTES with sufficiently wide Rexx numeric precision. Intended for diskFreeBelow watches and filesystem resource views. No new permissions.

Keep FsFile/FsFolder/Workspace and watch methods as the policy-facing surface. Explicitly close native roots/cursors/readers in success and failure paths; UNINIT is only a backstop. Do not grant raw provider objects or native routines to proposals. Claude independently confirmed dev5 122/122 on Jammy in REQ-00005733. This dev7 increment has 134 local checks (123 main, 10 registry, 1 compatibility fixture). No independent dev7, ED209 or integrated policy qualification yet. The historical sections below describe earlier increments and do not override this integration boundary.

## Build and test
Linux, C++11 compiler, ooRexx 5.3 headers and runtime. `REXX_INCLUDE=/path/to/include ./build.sh` then `NEWSHELL_HOME=/path/to/opt/newshell ./test.sh`. Set PATH, REXX_PATH and LD_LIBRARY_PATH for your ooRexx installation if not installed system-wide. Build on the target distribution; no container-built shared library is shipped.

## Trusted provider APIs
`POSIXProvider~stat(root, relative='.')` returns a Directory with OK, ERRNO, ERROR, and on success KIND, DEVICE, INODE, MODE (numeric permissions), MODE_OCTAL (four-digit octal string, e.g. 0644), UID, GID, LINKS, SIZE, MTIME_SEC/NS, CTIME_SEC/NS. `capacity(root, relative='.')` returns block/fragment/inode counts (not bytes). `pageSize` uses sysconf, in bytes. Root is absolute, target relative, no dot-dot, absolute target, embedded NUL, or symlink (including ancestors). Empty relative path is invalid; '.' selects root. Linux O_PATH/openat with nofollow and fstat; no shell invocation. Filesystem mount crossings are permitted. No file contents or writes. Root is opened anew for each call; no persistent root handle or guarantee against concurrent directory rename/mount changes. Metadata is an observation, not a mutation token. This is not a full containment sandbox; future write operations need a separately reviewed descriptor-based authority design and revalidation. Do not grant raw providers to proposals or allow arbitrary root selection by untrusted code.

`ProcessProvider` subclasses dev6 ProcessNativeProvider; existing ProcessRunner accepts it without change. Adds `observe(pid)` returning the existing LinuxProcess object or .nil, and `pageSize`. Inherits execution, reap and signal unchanged; these are trusted facilities, not new policy permissions. In the original dev1 implementation, LinuxProcess rssKiB assumed 4 KiB pages; new pageSize exposes the prerequisite for correcting this in the owning class. No new process mutation paths; PID-based signal remains the existing implementation, not PID-reuse safe by virtue of this adapter. LinuxProcess identity remains existing PID+starttime contract.

## Integration proposal
Keep FsFile/FsFolder and Workspace as policy-facing classes. Use POSIX metadata for consistent identity and capacity; do not make new providers directly reachable via public resource methods. Integrate through existing protected methods and authorityPath, without changing policy. A future Lock implementation needs proof of owner/process identity, plus atomic or protocol-coordinated removal: stat alone cannot prove staleness or prevent races. Next increment: bounded directory enumeration, descriptor-backed roots, guarded writes with policy tests, and process observation portability (page size and boot identity). No unconditional lock deletion, no raw command grant, no claimed production qualification.

## Qualification
22 original local checks against uploaded ooRexx 5.3.0 r13196 x86_64 and supplied dev6 native process library. See test-results.txt. No ED209 or Jammy target run, no mutation or proposal policy qualification, no upstream merge.

## dev2: descriptor-backed roots and bounded cursors
`r = provider~openRoot(absolutePath)` returns OK/ERRNO/ERROR and ROOT on success. `r['ROOT']~stat(relative='.')` and `~scan(relative='.')` resolve through Linux openat2 beneath the pinned directory descriptor, rejecting symlinks, magic links and ambiguous relative names. Requires Linux 5.6+ with permitted openat2 syscall and build headers; fails closed if unavailable. The legacy dev1 stat/capacity methods are unchanged and are not equivalent to pinned-root access. Mount crossings are allowed. A pinned directory continues to represent that directory after rename; it is not a pathname-based authorisation grant. Directory scans are live, not snapshots; names and inode/type hints are not authority or stable mutation identifiers. Concurrent relocation of an already opened directory can change its current pathname. No writes are implemented.

`scan` returns OK/ERRNO/ERROR and CURSOR on success. `cursor~nextBatch(limit=128)` returns ENTRIES (Array of Directory rows with NAME, INODE_HINT, TYPE_HINT [native d_type, may be DT_UNKNOWN]) and DONE. Maximum 1024 entries per call; DONE may only become true on the next empty batch. Links may be listed but are not traversed. Call `cursor~close` explicitly; `root~close` closes all its cursors. Closed/unknown handles fail; maximum 128 open roots and 128 cursors per process, serialized native operations. Handles are random 128-bit opaque bearer tokens, not caller-bound authorization; do not expose raw providers, handles or constructors to proposals. Explicit close is the rule; UNINIT is a garbage-collection backstop, not immediate release. Process exit reclaims descriptors. Names are native filename bytes, not necessarily UTF-8. No cross-process handle transfer or persisted cursor.

`ProcessProvider~observe` now returns a `NativeObservedProcess` subclass of the existing dev6 LinuxProcess, preserving PID/starttime identity and correcting rssKiB via native page size. Its conversion specifically assumes dev6 superclass rssKiB = pages * 4; the compatibility override delegates unchanged when the superclass exposes the PAGESIZEAWARE class method. Existing native process execution and signal semantics unchanged. No PID-safe signalling or new mutation.

47/47 local dev2 checks on supplied r13196 and dev6 (including original 22). Claude independently reproduced 22/22 for dev1 and 47/47 for dev2 on Ubuntu 22.04 (REQ-00005665 and REQ-00005679). Source only; compile on target.

## dev3: review corrections
- Both root and cursor have UNINIT cleanup, with explicit close clearing the token; no double-close of a subsequently opened resource. GC is nondeterministic: 128 abandoned handles can still temporarily exhaust the registry before a collection runs. Keep explicit close in long-running callers.
- Native handles are 32 hex characters generated from 16 bytes of Linux getrandom entropy, checked for collisions among active roots and cursors, and never issued if entropy fails. This prevents sequential guessing, not theft or deliberate sharing of a valid bearer token. Raw classes remain trusted only.
- MODE remains decimal for compatibility; MODE_OCTAL is a four-character string including leading zero. The deliberate rejection of symlinked roots includes standard Ubuntu paths such as /var/run; select /run explicitly if that is the authorized root.
- Observe the test interpreter PID via SysQueryProcess('PID') rather than assuming PID 1 is visible.
- Page-size-aware superclass marker is a CLASS method named PAGESIZEAWARE; adapter delegates without correction when present. Tested using an isolated fixture, not actual upstream dev7.
- 56 local checks on r13196/dev6, plus one marker-fixture check (57 total). Stress tests abandon 384 roots with cursors and separately 384 cursors, inducing GC between groups. Sequential guessed handles rejected. No actual dev3 Jammy or ED209 run, no new mutation, no proposal grants, no upstream merge.

## dev4: bounded file content and process inspection
`POSIXRoot~readAt(relative, offset=0, limit=65536)` returns OK/ERRNO/ERROR and, on success, DATA (binary Rexx string), BYTES, NEXT_OFFSET, EOF. Limits 1..1048576 bytes, nonnegative byte offsets within signed 64-bit range. EOF means a short read was observed; a full final chunk may require another call. The provider pins the root descriptor for the in-flight operation, resolves the target with openat2, checks regular-file type using O_PATH before opening for data through the trusted Linux /proc/self/fd interface, verifies device/inode, then uses pread. No pathname reopen, no FIFO/device opens for data. Linux procfs must be mounted and trustworthy. Root close prevents subsequent operations but does not cancel an already in-flight read. Every call opens the target afresh, so successive chunks are not an immutable snapshot or guaranteed to be from the same file. Regular pseudo-files and remote filesystems may still block; no deadline is implemented. No writes, no new policy grants; underlying read routine is trusted only.

`NativeObservedProcess~threadIds(limit=128)` and `~descriptorIds(limit=128)` return OK/ERRNO/ERROR, IDS (array of numeric-name strings), PID, START_TICKS, TRUNCATED. Limit 1..1024. Bounded live observation, not cursor pagination; TRUNCATED means more IDs were present. The native provider pins /proc/PID and verifies the expected start tick before and after listing; stale identity fails closed. Descriptor links are not followed or read, contents/targets are not exposed. Self-observation includes transient provider descriptors; IDs can disappear or be reused immediately. This uses PID+start-ticks within the local boot and PID namespace, not a durable remote identity, and is not a signalling authority. `threads` remains the existing numeric thread-count method. ShellProcessIds is an internal trusted routine; never expose to proposals. Actual upstream dev7 compatibility not tested.

Qualification: 76 local main-suite checks against supplied r13196/dev6 plus 1 isolated compatibility fixture (77 total). 20 additional checks include bounded offset reads, EOF, embedded NUL, FIFO rejection, symlink refusal, closed root, bounded process IDs and stale identity refusal. No upstream merge, independent Jammy dev4 run, ED209 qualification or policy-level integration. Earlier independent Jammy results cover dev1 and dev2 only.

## dev5: pinned readers, process credentials/limits, distinct registry errors
`r = root~openReader(relative)` returns OK/ERRNO/ERROR and READER on success. `reader~readAt(offset=0,limit=65536)` uses the same binary, bounded pread contract as dev4; `reader~stat` reads descriptor metadata. It retains the original inode through pathname rename, replacement or unlink. In-place writes/truncation are still visible: this is pinned identity, not immutable content or a snapshot. Use explicit close, even on errors. `reader~close` invalidates the handle; UNINIT is a GC backstop. Closing/collecting the parent root invalidates readers as well as directory cursors. Keep the root reachable while using its reader. An operation that has already duplicated its descriptor may finish after closure. Up to 128 readers in a third independent registry; opaque random tokens are checked against all three registries. No raw provider grant, no write API, no I/O deadline. Requires trusted /proc/self/fd as in dev4.

`NativeObservedProcess~credentials` returns PID, START_TICKS, REAL_UID, EFFECTIVE_UID, SAVED_UID, FILESYSTEM_UID, corresponding GID fields, GROUPS (up to 1024 supplementary IDs), GROUPS_TRUNCATED, and optional kernel fields CAP_INHERITABLE, CAP_PERMITTED, CAP_EFFECTIVE, CAP_BOUNDING, CAP_AMBIENT (hex strings), NO_NEW_PRIVS and SECCOMP when present. IDs are decimal strings. Capabilities are observations, not an authorisation grant. These are the Linux process leader's credentials in the visible procfs/user namespace, not guaranteed identical for all threads. No environment, arguments, secret material or arbitrary proc file access is exposed by this method.

`NativeObservedProcess~limits` returns PID, START_TICKS and LIMITS (array of Directory rows NAME, SOFT, HARD, UNITS). Soft/hard are exact decimal strings or `unlimited`; units may be empty. Uses the kernel /proc/PID/limits column header; rejects malformed/unrecognised layout rather than guessing. Both detail operations pin the process directory and verify start ticks before and after the read. Status/limits reads are bounded to 256 KiB; larger records fail EOVERFLOW rather than silently returning incomplete credentials. A read is a live observation, not proof that privileges or resource limits are still current. No process mutation or pidfd signalling is introduced. Internal ShellProcessDetails is trusted only.

When a registry is exhausted, `OK=0, ERRNO=0` and `ERROR` is `ROOT_REGISTRY_FULL (128 open roots)`, `CURSOR_REGISTRY_FULL (128 open cursors)` or `READER_REGISTRY_FULL (128 open readers)`. Native EMFILE remains a real operating-system error. Always check OK rather than inferring success from ERRNO alone. Explicit close restores capacity immediately; UNINIT remains nondeterministic.

Qualification: Claude independently confirmed dev3's 56 checks plus marker fixture on Jammy (REQ-00005695). Dev5: 111 main checks, 10 isolated registry checks, and one page-size marker fixture, 122 total, using uploaded r13196 and supplied dev6. Tests verify pinned reads across rename/replacement/unlink, in-place modification, sparse file seek above 4 GiB, UID/GID cross-check against kernel status, bounded groups, structured limits and stale PID rejection. Registry tests fill each registry, verify its distinct diagnostic, reclaim capacity via close, and exercise 384 abandoned readers under GC pressure. Sparse file fixture uses dd (no 4 GiB allocation); test environment must allow a sparse file of that size and at least 384 open provider descriptors plus runtime overhead. Tests require procfs, openat2 and standard Linux test utilities. Dev5 is source-only, not an upstream merge, and has no independent dev5 Jammy/ED209 qualification or policy-facing integration. Earlier limitations remain unless explicitly superseded above.

## dev15: Linux-to-object logging shim

Architecture: Tom Dyer. Coding and local qualification: ChatGPT.

This is a consolidated additive integration reference, not a replacement for the
published NewShell controller or the existing logging system. No auditd,
journald, rsyslog or systemd dependency is added. Existing dev14 interfaces are
retained; the shell event runtime can now bind a real Logging v0.7 LogService
before any sources are attached. The bridge is trusted host code, not a proposal
capability.

### Deployment example

```rexx
scope = .Log~internalScope('MU1-OPS')
service = .LogService~new('mu1-kernel')
target = .KernelLogTarget~new('kernel',scope,'target-incarnation-1',1024)
service~addTarget(target)
service~addRule(.LogRule~new('kernel-observe','kernel',,
  'KernelLogBridge','publish',scope,scope,.Log~INFO,.nil,.Array~of('kernel')))
bridge = .KernelLogBridge~new(service,scope,'MU1',bootId,collectorIncarnation)
rt~setObservationLogger(bridge)
/* Attach existing native watches, process handles and metric samplers. */
r = .POSIXProvider~new~openKernelLog
if r['OK'] then rt~attachKernelLog('printk',r['KERNEL_LOG'])
/* Caller retains and closes the kernel source. */
page = target~page('target-incarnation-1',0,128)
do event over page['EVENTS']
  say event~payload['KIND'] event~payload['INGRESS_ID']
end
```

- Linux printk reader uses `/dev/kmsg` character device 1:11, O_RDONLY,
  O_NONBLOCK, O_CLOEXEC, O_NOFOLLOW, and seeks to the live tail at open.
  It is a persistent epoll source with a registry of eight. No write or
  configuration operations, no dmesg command. Requires trusted /dev and kernel
  permission. Reads are capped at 16 KiB, drains at 32 records per pump. Header
  decode retains facility, severity, kernel sequence, monotonic microseconds and
  flags. Sequence gap, malformed header or read failure quarantines the source.
  The source can include userspace printk submissions; neither facility nor a
  message's contents constitute authenticated security evidence. No direct
  incident trigger on arbitrary printk text. Metadata-only by default; optional
  first 256 bytes as hex requires a SECRET-scoped runtime binding. Hex is not
  redaction. The native reader itself is trusted and receives raw bytes.
- KernelLogBridge uses loggerFor and LogActiveLogger~log with real registered
  rules, not hand-constructed LogEvent or bypass of LogService. Payloads are
  bounded Directory objects with node, boot, configured collector incarnation,
  ingress identity, monotonic/wall receipt time, kind, source and structured
  detail for known metric, PAM and printk observations. Source identities are
  trusted deployment configuration, not attested identities. Ingress ID
  uniqueness requires a fresh collector incarnation on restart.
- The runtime logs its native observations before evaluating a registered
  trigger, retains the ingress identity in the causal journal, and disarms the
  affected source if no logging route accepts the observation or serialization
  fails. Filesystem non-trigger observations also pass the bridge. Operational
  control/dispatch records remain in the existing runtime journal. Unbound
  runtimes retain compatibility behaviour; the deployment must bind the logger.
  Logging delivery means at least one configured target accepted, not durable
  storage or acknowledgement from every target. This is not a production
  mandatory-evidence policy implementation.
- KernelLogTarget is a bounded in-memory LogService target with exact delivery
  scope, target-local cursor, explicit incarnation and retention gaps. It
  preserves actual LogEvent objects, not copies. Trusted consumers must treat
  payloads as immutable. No queue durability, replay-to-action, or cross-domain
  transfer is implemented here. Existing Queue Fabric targets remain available
  for later integration with the same LogService. Target cursor is not global
  LogService sequence.
- KernelLogBridge~publishPam accepts a trusted structured PAM record, projects
  only known fields, and routes through a separately configured PUBLISHPAM
  LogRule. KernelPamLogConsumer pulls the actual LogEvent from KernelLogTarget,
  checks rule/class/method/exact scope/node/boot, then calls existing audit
  normalization and JobBoard runtime with original ingress identity. Starts at
  live tail, does not execute historical replay. Retention gap or disabled
  target observed during pull quarantines it. Disabling/re-enabling a target or
  producer between pulls can still produce an undetected gap: production needs
  source health/watermarks and durable receipts. Producer authentication is an
  external trusted-host responsibility. A caller must not allow untrusted direct
  target.accept or ingress calls. Actual PAM module and NETLINK_AUDIT multicast
  source are not included; tests use structured PAM fixtures. A pull scheduler
  or queue wakeup must be integrated by the owning host.

### Qualification

Rebuilt native package using g++ -Werror and supplied ooRexx 5.3.0 r13196;
full test.sh against supplied NewShell dev6 kit with LoggingCore v0.7: 411 PASS
lines (388 previous + 23 logging checks). Actual inotify event delivered by
LogService before governed review job; non-trigger file creation recorded;
PAM fixture delivered and consumed through LogService; rule disable prevents
trigger, scope denial, cursor gap and quarantine tested. Live /dev/kmsg absent
(ENOENT), direct printk data read/epoll test not run; decoder tested using
fixtures and explicit unavailable error tested. Existing live TCP_INFO test
also skipped (ENOENT). No live PAM authentication, independent Jammy/ED209,
Queue Fabric persistence, production security-policy integration or Git commit.
No raw capability is granted to proposals.

## dev16 — registered logging interests and priority isolation

Architecture: Tom Dyer. Coding and local qualification: ChatGPT.

Dev16 extends dev15 with configuration-time `KernelLogSubscriptions` and
`KernelPriorityLogTarget`. No changes to LoggingCore or native provider code.
Each subscription creates a genuine exact-scope `LogRule` with explicit named
points and an independent LogService target. One trusted bridge publisher per
registry and one acknowledged consumer per subscription; configure on one host
activity before binding. The receiver identity hash check is process-local
routing hygiene, not cryptographic producer authentication. Existing trusted
host/service authority remains the security boundary.

```rexx
scope = .Log~internalScope('MU-01')
service = .LogService~new('mu-logging')
subscriptions = .KernelLogSubscriptions~new(service,scope,4096)
auth = subscriptions~register('auth','auth-1','PUBLISHPAM',,
    .Array~of('USER_AUTH','USER_START','USER_END'),'CRITICAL',1024)
ops = subscriptions~register('operations','ops-1','PUBLISH',,
    .Array~of('IDENTITY_CHANGE','METRIC_HIGH','METRIC_RISE'),'OPERATIONS',1024)
diag = subscriptions~register('diagnostics','diag-1','PUBLISH',,
    .Array~of('TIMER','METRIC_BASELINE'),'DIAGNOSTIC',2048)
bridge = .KernelLogBridge~new(service,scope,'mu-01',bootId,incarnation)
bridge~bindSubscriptions(subscriptions)
page = subscriptions~next(128)
/* Process and verify the batch before acknowledging on its target. */
if page['SUBSCRIPTION']=='auth' then do
    /* inspect page['EVENTS'], page['GAP'], page['LOST'] first */
    /* auth~ack(page['GENERATION'],page['NEXT']) only after handling */
end
```

The registry is frozen after binding; rules and targets can be enabled/disabled
through existing LogService control. Existing unbound bridge behaviour retains
BODY point compatibility. In subscribed mode an exact method/event-point index
rejects unregistered kinds before constructing the observation payload or clock
snapshot. Registered mode's LogService point is the kernel event kind or PAM
record TYPE. For each required ShellEventRuntime source register ALL event kinds
it emits (including nontrigger observations), not merely trigger kinds:
unsubscribed mandatory events fail delivery and disarm as in dev15. This is
routing/filtering, not automatic kernel watch creation or event-rate reduction.

Capacity default 4096 aggregate event slots, configurable 1..65536; at most 64
subscriptions, 128 event points per subscription; total reserved slots cannot
exceed aggregate budget. Counts, not byte-perfect memory ceilings. Critical
lanes reject new on full, preserving older unacknowledged objects; other lanes
evict oldest on overflow. Sticky loss counters persist even after draining;
critical delivery remains failed until controlled replacement/reconciliation.
`next(limit)` services critical then operational then diagnostic lanes; lexical
lane order within priority, possible starvation; no global chronological order.
Use `status` even when `next` has no events to inspect losses/disabled state.
`read` and `page` offer cursor ranges; `ack(generation,through)` cannot pass
highest offered cursor and releases retained objects. An ack is local consumer
progress, not a durable Queue Fabric receipt. Critical overflow or missing
required rule delivery cannot be masked by a successful diagnostic mirror.
The trusted runtime disarms affected triggers when this receipt fails.

Local validation: full rebuild and regression on supplied r13196 and dev6 kit,
444 PASS lines (411 prior + 33 priority checks). Actual LogService registrations,
wrong scope and receiver refusal, diagnostic flood isolation, critical reserve
and full failure despite mirror, disabled required rule loss accounting,
priority drain, generation/ack refusal, explicit gap, real inotify overload
preventing governed job execution. Initial test assertion incorrectly assumed
Directory index case folding; corrected expectation and reran full suite.
Live printk absent and TCP diagnostic interface unavailable as in dev15.

Limits: RAM only; no automatic durable spill, native source subscription
lifecycle, byte-rate prioritisation, fairness scheduler, dynamic subscription
configuration or production policy integration. Direct raw payload access is
trusted as in Logging v0.7; no grant of access to untrusted proposals. Mandatory
security lanes must be reconciled by the host after gaps; no automatic reset.
Existing KernelPamLogConsumer uses the original KernelLogTarget; acknowledged
priority lane consumption is a separate interface, not yet an automatic PAM
normalisation/Queue Fabric consumer. Not independently qualified or published.
