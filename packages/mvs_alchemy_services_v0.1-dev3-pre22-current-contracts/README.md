# PRE17 — MVS typed payload regression lock

PRE17 retains PRE16's explicit ASCII 414C4348 protocol eye and adds a static
decoder for every fixed guest typed-value payload. The checker models runtime
HANDLE slots as four-byte values and validates type, tag, and value lengths for
HELLO, PING, Queue, DB, IMAP, SMTP, and PATH request templates against the
`MasWire.cls` typed-value contract. No transport or service semantics changed.

PRE17 is NOT_RUN live on ED209Z until this exact archive is submitted through JES.

---

# PRE16 — byte-exact mvs.alchemy/1 eye repair

PRE16 fixes a post-carrier framing defect found by auditing the actual MVS source.
MVS assembler character constants are EBCDIC, so `C'ALCH'` produced C1D3C3C8,
not the protocol eye 414C4348 used by the Linux ooRexx gateway. MASLIVE now emits
and verifies the eye as explicit hex `X'414C4348'`. X'75' transport choreography
is unchanged. `scripts/check_mvs_wire_bytes.py` regression-locks this boundary.

PRE16 is NOT_RUN live on ED209Z until this exact archive is submitted through JES.

---

# MVS Alchemy Services dev3-pre22 — RPC Service Core aligned X75 qualification line

pre9 is the first delivered cut containing executable MVS guest transport code.
It does **not** retroactively validate the previously claimed dev2 artifact; see
`docs/PROVENANCE_RESET_2026-10-05.md`.

New executable material:

- `mvs/asm/MASD75.asm` — direct Hercules X'75' transport on MVS 3.8J/TK5;
- `mvs/asm/MASLIVE.asm` — live guest IVP for Queue, DB, IMAP, SMTP and PATH;
- `HOST/src/MasWire.cls` — executable `mvs.alchemy/1` codec;
- `HOST/src/MasLiveGateway.cls` — ooRexx host endpoint with Logging v0.7;
- `scripts/qualify_ed209c_ed209z_services.sh` — full environment qualification.

Host-side gateway qualification passes under ooRexx 5.3.0 r13196.  ED209Z
assembly/link/execution is **NOT_RUN** in this build environment and must be
qualified with the supplied environment script.

---

# MVS Alchemy Services (MAS) v0.1-dev3-pre6

Unqualified BASE-1 candidate for MVS 3.8j TK5 under Hercules, built incrementally from the supplied v0.1-dev2 BASE-0.5 package.

Dev2 remains the authority for the already-qualified pre-transport frame/typed/replay reference. This pre1 adds the BASE-1 transport boundary, live-IVP gate, personality reservations, LDAP design boundary, and a deliberately failing S/370 MASIVP1 safety stub. It does **not** guess the DYN75 calling convention and does **not** claim a live Hercules crossing.

## Reference checks

From the package root:

    python3 HOST/tests/wire_reference.py
    python3 host/reference/selftest.py

Expected:

    MAS BASE-0.5 wire/typed/replay reference: PASS
    MAS dev3-pre1 wire reference: PASS

## Qualification

`qualification/BASE1/qualification.txt` is `NOT_RUN / UNQUALIFIED`. BASE-1 is reserved for the real TK5+DYN75+ooRexx endpoint evidence described in `qualification/BASE1/README.md`.

Alchemy Objects v0.8.1 and the Alchemy LDAP / Identity Directory library are external dependencies and are not vendored.

## dev3-pre2 increment

Adds an executable stream-framing and BASE session reference: fragmented/coalesced
frames, HELLO/ACCEPT, PING/COMPLETE, DISCONNECT, replay of identical requests,
replay-conflict rejection, and a full 0x00..0xFF opaque-byte round trip. MASD75
remains deliberately unimplemented until its real TK5/Hercules DYN75 calling
convention is derived from authoritative material and qualified live.

## dev3-pre5 update

This cut binds the planned MAS/LDAP personality to the actual public development surface found in `oorexx_ldap_identity_v0.1-dev10`, including `LdapConversationService`, `NativeLdapPersonality`, the neutral semantic identity model, and the explicit authentication/operation-authority split. See `spec/alchemy-ldap-binding.md`. No live DYN75/TK5 qualification is claimed.

## pre4 mail increment

pre4 reserves `1400-14FF` for MAS/MAIL and binds its design to the current
secure SMTP dev4 contract plus the available IMAP API evidence.  The reference
policy test intentionally has no unsigned-relay compatibility argument:
verified user-bound signature + independent `EMAIL_SEND` authority + egress
policy are mandatory before relay can become eligible.

BASE-1 remains unqualified; this mail increment does not substitute for the
real TK5/DYN75 qualification gate.

## pre5 executable MAS/MAIL reference

The mail personality now has executable bounded semantics rather than only a
design note. `mail_personality_reference.py` models mailbox/message/draft
handles, UIDVALIDITY-aware lookup, catalogue paging, bounded BYTES body/part
reads and the outbound hard gate. Wire operation numbers are assigned inside
`1400-14FF`. This remains a host reference; no DYN75/TK5 qualification claim.

## dev3-pre6 virtual services increment

pre6 corrects the gap between reserved/planned services and executable delivery.  It adds a provider-neutral host facade with executable qualification providers for all four MVS-visible service families: queue, database, IMAP projection and SMTP submission.  Queue remains FIFO/opaque-byte; database is a bounded generic key/value compatibility personality in the reserved `1100-11FF` range; IMAP and SMTP now dispatch through explicit provider interfaces while preserving the existing MAS/MAIL security rules.

This does **not** claim that the in-memory providers are production Queue Fabric/NoSQLServer/IMAP/SMTP protocol stacks, and it does not claim live ED209Z DYN75 qualification.  Those production packages bind behind the provider interfaces.

## pre7-dsfs: Storage Fabric MVS path personality

Adds executable DSFS-like `PATH` virtualization backed by Storage Fabric identity
and namespace objects, plus TEXT/BINARY/RECORD views and a Hercules-compatible
AWSTAPE directory projection. See `spec/storage-fabric-dsfs-personality.md`.

## dev3-pre8-dsfs-durable increment

pre8 closes the pre7 memory-only qualification gap by adding a restartable
host-backed Storage Fabric object-store binding. Each close publishes a new
immutable object file and journal record; restart reconstructs the Storage
catalogue and current namespace bindings without discarding older StorageRefs.

It also adds a transport-neutral PATH session dispatcher with
OPEN/READ/WRITE/APPEND/CLOSE/STAT/LIST operations. This is the semantic endpoint
a future ED209Z/ED209ZZ guest carrier binds to; pre8 still does not pretend that
MVS 3.8J JCL PATH interception already exists.

`HOST/tools/aws_inspect.py` independently validates generated Hercules AWSTAPE
images. `HOST/tools/hercules_tape_plan.py` emits an observation/mutation plan but
never executes DEVINIT itself.


## PRE10 JES-gated live qualification

PRE10 does not interpret a socket-reader connection as guest execution. The environment test first submits a small `MASRDR` job and requires JES2 `$HASP100`, `$HASP373`, and `$HASP395` evidence. It then submits `MASLIVE` and separately records JES acceptance, start, end, guest WTO facility markers, X'75' gateway traffic, and Logging v0.7 evidence. An interrupted run is `INCONCLUSIVE`, not `FAIL`.

## dev3-pre11 live guest build repair

PRE10 reached a healthy ED209Z and JES2, then failed in the guest build. PRE11
removes the hidden EZASMI/EZASOH03 dependency: `MASD75.asm` now issues the
Hercules TCPIP X'75' instruction directly using the documented register
conversation protocol. `MASLIVE.asm` no longer uses symbolic fullword literals
that Assembler XF rejected, and assembler source cards are limited to 71
columns so column 72 cannot accidentally request continuation.

The qualification harness also preserves literal `$HASP...` regexes across the
remote shell and classifies a completed job with assembler/link/spool errors as
FAIL instead of INCONCLUSIVE. PRE11 itself remains NOT_RUN on ED209Z until the
unchanged archive is submitted through the complete environment test.


## dev3-pre12 direct X'75' bounded qualification cut

PRE12 retains the direct Hercules X'75' guest transport from PRE11 and adds bounded blocking semantics for CONNECT and RECEIVE. Hercules native result is retained in MD75RET; MD75ERR=1 means X'75' instruction failure, 2 means qualification wait exhausted, and 3 means a native socket/function failure. CONNECT/RECEIVE retry -2 with a five-hundredth-second STIMER wait and a 600-try bound (30 seconds per wait interval). PRE12 remains NOT_RUN on ED209Z until the unchanged archive is assembled and executed there.

## dev3-pre14 HASP-safe qualification harness

PRE14 repairs the remaining `set -u` regression in the live qualification
harness.  The reader/JES success message no longer expands `$HASP100` as a
shell variable after the literal-safe JES regex has matched.  PRE14 also ships
a harness-safety checker that rejects executable double-quoted `$HASPnnn`
status prose.  HASP regexes remain literal (`\$HASP...`) where required for
log matching.


## dev3-pre14: live X'75' runtime repair

PRE12 was run through live JES on ED209Z. MASD75 assembled RC=0, MASLIVE
assembled RC=4, link RC=0, and RUN abended S0C4 with the saved PSW at the
X'75' instruction. No guest request reached the host gateway.

PRE14 reconciles MASD75 with the proven EZASOH03 CALLPC sequence exactly:

- guest-to-host phase: `DC X'75005000'` using R5 as the RX base register;
- host-to-guest phase: `DC X'75006000'` using R6 as the RX base register.

PRE12 incorrectly used `75006000` for both phases and copied R5 into R6.
For this stateful/restart-sensitive Hercules extension that substitution is
removed. PRE14 also fixes the live RC=4 warning: TCP port 37075 does not fit
in a signed H constant, so the control block stores the raw unsigned network
port value as `X'90D3'`.


## dev3-pre15 — X'75' live diagnostics

PRE15 keeps PRE14's exact `X'75005000'` / `X'75006000'` reference
choreography. It does not change the MAS wire or service semantics.

The live qualification control block enables a low-volume MASD75 trace around
INITAPI, SOCKET and CONNECT so a guest program interruption can be assigned to
a native X'75' function from the MVS/Hercules log. Production callers may leave
`MD75FLAG` bit 0 clear.

The environment X'75' preflight is also scoped to the latest Hercules process
startup and the latest `ipl 0390` in that lifetime; an old facility line from a
previous emulator lifetime can no longer satisfy the gate.

## dev3-pre20 — Instrumentation Mesh integration

PRE20 consumes `oorexx_instrumentation_mesh_v0.1-dev3` as the estate-wide
observation layer.  The core gateway remains dependency-neutral: it accepts an
optional observer and does not acquire telemetry transport, history or command
authority itself.  `MasInstrumentationAdapter.cls` wraps one shared
`InstrumentationEmitter` for the resident gateway instance and reports generic
request/inflight/byte counters plus MAS session, frame and per-operation
counters.

Logging v0.7 remains the authoritative qualification/audit event stream with
run/request/transaction correlation.  Instrumentation Mesh is operational
telemetry; it does not replace Logging evidence and grants no service mutation
authority.

The full environment test now stages the exact Mesh dev3 dependency, runs the
adapter smoke test, starts the instrumented gateway and retains
`instrumentation.tsv` alongside the Logging v0.7 evidence.  Live PASS requires
request/session gauges to settle back to zero and byte counters to exist.

PRE20 has not been live-qualified on ED209Z.  PRE17/PRE15 X'75' live status is
not promoted by this telemetry increment.

### Current Library provider review (2026-10-08)

PRE20 also refreshes the documented provider targets to the current Library
heads: NoSQLServer v0.87 instrumented bulk, IMAP dev12, SMTP Secure Stack dev8,
and LDAP Identity dev14.  See `spec/current-production-bindings.md`.  These are
reviewed integration targets only; PRE20 does not claim a live production
provider binding through MVS.

## dev3-pre20 — collector-ready Instrumentation Mesh

PRE20 keeps Logging v0.7 as correlated qualification/audit evidence and deepens
optional `instrumentation.mesh/0.1` observation.  MAS metrics now carry stable
product/release/protocol and guest/host dimensions, while operation telemetry
uses a bounded metric vocabulary plus `operation`, `operation_code` and `family`
dimensions.  `MasInstrumentationSource~capability` advertises observation only:
no instrumentation mutation commands are exposed.

The ED209C environment qualification now runs a process-local real Mesh
publication path (`InstrumentationRegistry` -> `InstrumentationService` ->
`InstrumentationPublisher` -> `InstrumentationCollector`) and proves lookup and
series retrieval by stable `semantic_ref`.  The live gateway evidence TSV also
retains sample dimensions.  PRE20 does not claim a remote Queue Fabric
instrumentation carrier or production NoSQL/IMAP/SMTP bindings.


## dev3-pre20 — ConnectSelector + production SMTP authority

PRE20 consumes the new `oorexx.connect_selector/0.1` contract as the sole
host-side communication selector. `MasConnectSelectorPort` is a thin injected
port for DirectCall/JSON-RPC requests, notifications, and explicit QueueFabric
enqueue. It does not choose service operation names and it never retries on a
different connector after execution starts.

The Queue personality remains deliberately unbound to ConnectSelector QUEUE:
current MAS QPUT/QGET/QDEPTH reply semantics are stronger/different from an
acknowledged enqueue and must not be faked.

SMTP production integration now follows SMTP Secure Stack dev8's reviewed MAS
binding. Providers exposing `signFor`/`submitFor` require trusted host principal
attribution; guest VERIFIED/AUTHORIZED/EGRESS values are fixture data only and
cannot grant production authority.

## dev3-pre22 RPC Service Core alignment

PRE22 updates the host interconnect boundary to ConnectSelector dev2 and adds a
protocol-neutral adapter for RPC Service Core dev1.  Explicitly published object
methods can now be dispatched through `RpcServiceRegistry`/`RpcServiceDispatcher`
and consumed through ConnectSelector's DIRECT request path without teaching MAS
about JSON-RPC, SOAP, protobuf, sockets or QueueFabric internals.

JSON-RPC Fabric dev3 has not yet adopted RPC Service Core, so PRE22 does not
claim network RPC integration through the common registry.  See
`spec/rpc-service-core-binding.md`.


## dev3-pre22 — current contract reconciliation (2026-10-24)

PRE22 rebases the host-side integration boundary onto current reviewed project artifacts: ConnectSelector dev6, RPC Portfolio dev1/RpcServiceCore dev1 and Instrumentation Mesh dev8. The PRE21 duplicate `MasRpcCoreConnector` is removed; local RPC-Core dispatch now uses ConnectSelector's qualified `ConnectRpcDispatchAdapter`. Current production targets are recorded as SMTP dev11, NoSQLServer v0.91 candidate and LDAP Identity dev19 candidate, with their qualification caveats preserved. The MVS X'75' carrier and wire framing are unchanged and PRE22 remains NOT_RUN live on ED209Z.
