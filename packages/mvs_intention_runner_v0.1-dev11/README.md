# MVS Intention Runner v0.1-dev9

Discovery-first plain-English control surface for MVS.

The model does not construct JSON request state, remember JES IDs, choose 3270 coordinates, or manufacture MVS commands. Before **every** Intention proposal the runner refreshes safe evidence from independent authorities.


## dev9 — non-blocking 3270 AID semantics

Live qualification on both ED209Z and ED209ZZ proved that the password was
accepted and a HERC03 TSO address space was started (`$HASP100`/`$HASP373`)
while the scripted `Enter()` action was still waiting for a keyboard unlock.
The test timeout then killed the 3270 client, producing `IKT108I ... WAITING FOR
RECONNECT`.  This was a controller-semantics defect, not an authentication
defect.

The authenticated reference adapter now launches s3270 with `AidWait` clear.
AID actions therefore transmit immediately; completion remains owned by the
existing current-screen state machine and bounded `Wait(Output)` observations.
The same TN3270 process/session is retained throughout.  No new authority is
created and no write-capable TSO surface is exposed.

## dev7 — live TK5 password prompt + failure evidence corrections

Dev7 is driven by live dev6 qualification against both cleanly re-IPLed TK5 guests.
ED209Z and ED209ZZ both presented the real TK5 Update 5 prompt
`ENTER CURRENT PASSWORD FOR HERC03-` after userid submission. The adapter now
recognises that exact prompt family explicitly instead of relying on a generic
PASSWORD substring. A password is still never sent unless the current screen is
positively identified as a supported password prompt.

A second live-path defect was also corrected: failure transcripts are now retained
and credential-scrubbed. During regression work this exposed a Bash command-substitution
state-loss bug in the old capture path; action results are now carried in controller-owned
shell state, so screen observations and transcript evidence survive in the same process.

The authenticated x3270 reference adapter keeps one s3270 process/session from
initial screen discovery through LOGOFF. It observes the current screen before every
state transition. Credentials are entered only after a TSO `Logon ===>` panel and a
positive password prompt have been observed. Authentication requires an exact `READY`
line on the current screen; command names, generic IKJ messages, and echoed input are
not authentication evidence.

The documented TK5 post-logon path is bounded: two ENTER acknowledgements and PF3
from the ISPF primary menu. The only TSO commands are the fixed read-only catalogue
`PROFILE`, `LISTCAT LEVEL(userid)`, `LISTALC STATUS`, followed by `LOGOFF`. Dataset
facts are parsed only from the captured LISTCAT result screen.

Reference TSO evidence now retains target, host and LU alongside the authenticated
user, with provenance remaining `REFERENCE_TSO_X3270`; it is never relabelled as
Terminal Machine or MVS Alchemy authority. Negative qualification proves that a rejected login containing the text
`LISTCAT LEVEL(...)` cannot become authenticated or create dataset evidence. A second
negative regression proves that an unrecognised password screen fails before credential
entry while still retaining a redacted diagnostic transcript.

## dev2: three independent discovery planes

`MvsDiscoveryComposer` composes:

1. **MVS Alchemy** — guest/MVS semantic truth: system identity, JES, datasets and target-native facts.
2. **Terminal Machine** — what the 3270 session actually presents: session/screen/field/cursor/keyboard/TSO-visible state.
3. **Hercules Services** — emulator/control-plane truth: process/control/guest/device/endpoint observations.

The facts retain source and evidence reference. They are **not** collapsed into one health bit. If Hercules reports `GUEST=STOPPED` while MVS Alchemy still reports `JES=READY`, dev2 retains both observations. Higher reasoning gets the contradiction rather than a fabricated consensus.

The shipped three-plane fixture performs 17 safe probes per turn (7 MVS + 4 terminal + 6 Hercules). The number is deliberately uninteresting: broad safe discovery is allowed if it narrows the intention correctly.

## Discovery before proposal

The qualified invariant is:

```text
plain English
    -> refresh all configured safe discovery sources
    -> retain source/provenance and contradictions
    -> project authoritative semantic scope
    -> publish IntentionEvidenceFact records
    -> propose / clarify / READY
```

The exact same utterance:

```text
find the last failed compile for Fred
```

selects `JOB00140` in discovery generation 1 and `JOB00144` after the MVS source changes. The LLM did not remember either ID.

## Provider-neutral live feed

Real authorities bind through a deliberately tiny controller-owned TSV projection. This is **not** an LLM protocol; it is an adapter seam between authoritative components and the runner.

```text
PROBE<TAB>name<TAB>detail
FACT<TAB>subject<TAB>predicate<TAB>value<TAB>quality<TAB>evidence-reference
```

Files in one discovery directory:

```text
mvs_alchemy.tsv
terminal_machine.tsv
hercules_services.tsv
```

`MvsDiscoveryDirectoryBackend` re-reads them on every utterance. A live provider can therefore change underneath a long-running language session and the next proposal sees the new world.

Example MVS semantic rows currently understood by the first slice:

```text
FACT  SYSTEM             NAME   ED209Z
FACT  SYSTEM             OS     MVS 3.8J TK5
FACT  JES                STATE  READY
FACT  TSO                USER   HERC01
FACT  JOB.JOB00140       ROW    JOB00140|PAYCOMP|FRED|COMPILE|ENDED|CC 0012|...|FRED.COBOL(PAYROLL)
FACT  DATASET.FRED.COBOL ROW    FRED.COBOL|PDS|TRUE
```

Terminal Machine owns `SESSION STATE`. Hercules Services owns `GUEST STATE` and `CONTROL STATE`; those do not overwrite MVS facts.

## Current MVS Alchemy boundary

Library `mvs_alchemy_services_v0.1-dev3-pre13-hasp-safe` is a real `mvs.alchemy/1` guest transport/gateway qualification line. It does not yet expose a convenient JES/dataset discovery facade, so dev2 does **not** pretend the transport is already that API. A future MAS adapter should interrogate its real semantic service and emit the above facts.

Likewise, no shell/log scraper is labelled `HERCULES_SERVICES` and no raw `s3270` script is labelled `TERMINAL_MACHINE`. Qualification shortcuts must not acquire false authority.

## Qualification

Core, fixtures, contradiction retention, dynamic scope and provider-feed tests:

```sh
OOREXX_DEB=/path/to/oorexx-5.3.0-r13196.deb \
  ./tools/run_environment_test.sh
```

Interactive fixture:

```sh
rexx examples/mvs_intention.rex ED209Z
```

Interactive provider feeds:

```sh
MVS_DISCOVERY_DIR=/path/to/current/discovery \
  rexx examples/mvs_intention.rex ED209Z
```

## Full live environment qualification

`tools/run_live_environment_test.sh` is the end-to-end environment harness. It requires three **real provider adapter commands**; each receives the target as its first argument and emits the canonical TSV to stdout:

```sh
MVS_ALCHEMY_DISCOVERY_CMD='/path/to/mas-discover' \
TERMINAL_MACHINE_DISCOVERY_CMD='/path/to/terminal-machine-discover' \
HERCULES_SERVICES_DISCOVERY_CMD='/path/to/hercules-services-discover' \
MVS_INTENTION_TARGET=ED209Z \
OOREXX_DEB=/path/to/oorexx-5.3.0-r13196.deb \
  ./tools/run_live_environment_test.sh
```

If an authority is unavailable the live qualification is `BLOCKED`; the script does not silently replace it with a lower-authority shell or screen scraper.

## Deliberate dev2 boundary

Everything dispatched by this package remains **READ_ONLY**. Discovery may be broad; mutation is a later authority/confirmation layer. This cut exists to prove that MVS scope can be discovered cheaply and correctly before we let an LLM ask to change anything.

## dev3: x3270-family reference qualification

For initial live MVS qualification, dev3 deliberately does **not** require the in-development Terminal Machine implementation to be correct before MVS Intention can be tested.

A reference adapter uses the mature x3270 family:

- `s3270` for automated, repeatable discovery;
- `c3270` for an optional human-visible witness of the same terminal path.

The automated adapter is `tools/x3270_reference_discovery.sh`. Its safe action sequence is bounded to:

```text
connect
observe initial screen
Reset()
Clear()
observe resulting screen
disconnect
```

On the established TK5 LU `00C0` path, Reset/Clear is the already-qualified transition from the Hercules/TK5 welcome panel to the MVS `Logon ===>` panel. Dev3 records only structural evidence such as session state, screen class and known screen markers. It never logs credentials.

The x3270 adapter is explicitly labelled **REFERENCE_X3270** evidence in qualification usage; it must not be relabelled `TERMINAL_MACHINE`. When Terminal Machine is ready, the same MVS interaction can be observed through both implementations and compared differentially.

Fixture qualification:

```sh
./tests/test_x3270_reference_adapter.sh
```

Full reference-terminal environment test:

```sh
MVS_INTENTION_TARGET=ED209Z \
X3270_HOST=alchemyrexx.duckdns.org \
X3270_PORT=3270 \
X3270_LU=00C0 \
  ./tools/run_x3270_reference_live.sh
```

For a visible human witness, the live script prints the corresponding `c3270` command. The test stops at the TSO logon panel; it does not log on, submit work, or mutate guest state.

End-to-end reference discovery into Intention itself:

```sh
MVS_INTENTION_TARGET=ED209Z \
X3270_HOST=alchemyrexx.duckdns.org \
X3270_LU=00C0 \
OOREXX_DEB=/path/to/r13196.deb \
  ./tools/run_x3270_intention_live.sh
```

This test expects `what can I see` to become READY with `terminal=TSO_LOGON` from a freshly generated `reference_x3270.tsv`. Missing MVS Alchemy/Hercules/Terminal Machine feeds remain explicitly unavailable; x3270 is not promoted to any of those authorities.

## dev4: live ED209Z qualification corrections

The first real workstation qualification of dev3 against ED209Z on 2026-10-06
proved the reference path end-to-end and exposed two harness assumptions.  Dev4
locks both corrections into the package:

1. `s3270` waits for `3270Mode`, not the invalid `Wait(Connect)` action used by
   dev3.
2. target identity and network endpoint are separate.  The shared/default
   DuckDNS name had moved to ED209ZZ/ED209I, so ED209Z must never silently follow
   that name.  `config/x3270_targets.tsv` maps the known qualification targets
   explicitly and an unmapped target fails closed unless the caller supplies
   `X3270_HOST` (or a HOST argument).

The live run reached the real MVS 3.8J/TK5 `Logon ===>` panel on ED209Z through
LU `00C0`, then MVS Intention consumed the fresh reference feed as
`terminal=TSO_LOGON`.  No credentials, TSO commands, JES work or dataset
mutation were used.  This is reference-terminal qualification only; it does not
claim Terminal Machine authority.

Dev4 also retains safe structural terminal evidence from the x3270 status line:
negotiated 3278 model, rows, columns and cursor row/column.  These facts remain
`REFERENCE_X3270` observations and can be used for differential qualification
when Terminal Machine is attached later.


## dev5: authenticated read-only TSO discovery and evidence gates

The second ED209Z workstation qualification exposed two real delivery defects in
`dev4`, both now regression-locked:

1. the automated x3270 adapter must invoke `s3270 -script`; without script mode
   the delivered adapter could return no screen evidence while still exiting
   successfully;
2. recognition is not feasibility. `SYSTEM_IDENTITY`, `LIST_JOBS`, and
   `LIST_DATASETS` are no longer proposed READY merely because their English
   phrase is understood. They require corresponding discovered evidence.

With only an unauthenticated `REFERENCE_X3270` TSO logon screen:

```text
what can I see       -> READY (the terminal scope is directly observed)
what system am I on  -> not READY (no MVS system identity evidence)
show jobs            -> not READY (no JES evidence)
show datasets        -> not READY (no dataset catalogue evidence)
```

### Authenticated TSO reference oracle

`tools/x3270_tso_read_discovery.sh` adds a deliberately bounded authenticated
reference path for the disposable TK5 development guests. It is still an
**external qualification oracle**, not Terminal Machine and not MVS Alchemy.

The script has no arbitrary command argument. After logging on it can execute
only this fixed read-only catalogue:

```text
PROFILE              (no operands; display current TSO profile)
LISTCAT LEVEL(userid) (catalogue discovery scoped to the test userid)
LISTALC STATUS        (current allocation observation)
LOGOFF                (session teardown)
```

The public TK5 test configuration supplies default test identities. The harness
uses the ordinary `HERC03` test account by default; `TSO_USER` and
`TSO_PASSWORD` may override it for an explicitly authorised qualification.
Credentials are never emitted as `FACT` values. Retained transcripts are
redacted if the supplied password appears unexpectedly.

Directly observed catalogue entries are emitted as
`REFERENCE_TSO_X3270` dataset facts. They may satisfy a read-only dataset-list
intention because the dataset names were observed from the running guest, but
they do not manufacture DSORG/writeability, JES state, or system identity.

Fixture regression:

```sh
./tests/test_x3270_tso_read_adapter.sh
```

Authenticated live qualification:

```sh
MVS_INTENTION_TARGET=ED209Z \
X3270_HOST=52.146.17.8 \
TSO_USER=HERC03 \
TSO_PASSWORD='<authorised TK5 test password>' \
OOREXX_DEB=/path/to/r13196.deb \
  ./tools/run_x3270_tso_intention_live.sh
```

The live harness first proves the unauthenticated TSO logon panel, then logs on,
performs the fixed read-only discovery, logs off, and runs four English
requests. Exactly the requests supported by current evidence may become READY.
In particular, no authenticated 3270 session can make `show jobs` READY until a
JES authority actually supplies JES evidence.

### Dual live qualification

For the clean two-guest environment, `tools/run_dual_mvs_x3270_tso_live.sh`
executes the complete authenticated read-only reference qualification against
both canonical endpoints and verifies guest/host evidence separation.  It is a
qualification harness, not an authority adapter.


## dev9: native Terminal Machine boundary

dev9 consumes the current Terminal Machine v0.22-candidate8 3270/TN3270E slice
directly.  The new `terminal_machine_tso_discovery.rex` adapter owns no terminal
implementation itself: it composes `TcpTerminalTransport`, `TN3270Wire` and
`TN3270LiveSession`, then publishes only bounded Terminal Machine observations
through the existing controller TSV boundary.

This supersedes the architectural role of the dev6-dev8 s3270 authentication
driver.  `s3270/c3270` remains an independent `REFERENCE_X3270` qualification
oracle; it is not relabelled as Terminal Machine authority.

The native adapter uses presentation-space generations as the completion
boundary for AID actions, native unprotected-field discovery for userid,
password and LOGOFF input, exact positive TSO READY observation for
authentication, and a verified LOGOFF back to `Logon ===>` before closing.
It does not run LISTCAT, JES commands or arbitrary TSO commands: those belong
to MVS Alchemy/JES authority rather than the terminal plane.

Current Terminal Machine dependency qualified for this package:

- `oorexx_terminal_machine_v0.22-candidate8.zip`
- SHA-256 `006f448319dd210fa04fb7b5d02fd149a1db7f06c8837dd73a94316783e86365`
- SSC sourceLevel 6
- candidate8 includes basic TN3270E, structured-field/query reply support,
  partition-00 I/O, executable Read Modified All / Erase All Unprotected,
  native field/operator input, and current r13196 Socket short-send/select
  handling.

Complete real-environment dual-guest qualification:

```sh
export TERMINAL_MACHINE_ROOT=/path/to/oorexx_terminal_machine_v0.22-candidate8
export OOREXX_DEB=/path/to/oorexx-5.3.0-r13196.deb
export TSO_USER=HERC03
export TSO_PASSWORD=PASS4U
./tools/run_dual_terminal_machine_tso_live.sh
```

The harness independently proves:

- ED209Z -> `52.146.17.8` -> LU `00C0`;
- ED209ZZ -> `20.114.63.150` -> LU `00C0`;
- positive native Terminal Machine `TSO_READY` and authenticated-session facts;
- clean LOGOFF back to TSO Logon;
- no cross-target evidence contamination.


## dev10: current Terminal Machine + MVS Alchemy JES completion truth

dev10 preserves dev9's authority split and makes two independent updates.

First, the native terminal consumer is requalified against
`oorexx_terminal_machine_v0.22-candidate13`.  candidate13 is the current 3270 P0 line. It inherits candidate12's evidence-backed `MVS.ISPF.PRIMARY_OPTION_MENU` and exact-row TSO READY behaviour, and adds `S3270Reference.cls` plus semantic differential comparison of dimensions, cursor, visible rows, field geometry/protection/numeric/MDT/NONDISPLAY state. The native `TN3270LiveSession` generation/AID surface consumed by this runner is unchanged from candidate12.

Second, MVS Alchemy Services PRE23 contributes a stricter JES completion
contract.  A guest facility marker such as `MASLIVE PASS ALL` is not sufficient
to declare a job successful.  When PRE23 completion-gate evidence is present,
the runner derives:

- `INCOMPLETE` until `JES_ENDED=TRUE` (HASP395) and
  `SPOOL_RETAINED=TRUE`;
- `SUCCESS` only after those two gates and `FACILITY_PASS=TRUE`;
- `FAILED` after completion/spool evidence when `FACILITY_PASS=FALSE`.

Historical MVS feeds without PRE23 gate facts remain readable and are labelled
`SUCCESS_LEGACY` / `FAILED_LEGACY` rather than being silently promoted to the
new evidence strength.

Canonical MVS Alchemy job facts added by dev10 are:

```text
FACT  JOB.<id>  JES_ACCEPTED    TRUE|FALSE
FACT  JOB.<id>  JES_STARTED     TRUE|FALSE
FACT  JOB.<id>  JES_ENDED       TRUE|FALSE
FACT  JOB.<id>  SPOOL_RETAINED  TRUE|FALSE
FACT  JOB.<id>  FACILITY_PASS   TRUE|FALSE
```

The job `ROW` remains backward compatible.  Completion-gate facts are projected
only from `MVS_ALCHEMY`; Terminal Machine continues to own terminal/session
truth and s3270/c3270 remains reference evidence only.

New regressions:

- `tests/test_mas_pre23_completion_gate.rex`: proves a facility PASS before
  HASP395/final spool is still INCOMPLETE and becomes SUCCESS only after both;
- `tests/test_terminal_machine_candidate13_compat.sh`: compiles the native
  adapter against candidate13 and runs the focused 3270/TN3270/TN3270E,
  snapshot, MVS known-state and ownership suites.

Live Z/ZZ qualification remains a real-environment gate.  dev10 does not claim
that simply because candidate13 and PRE23 have their own retained evidence.

Candidate13 itself is qualification-pending until its new s3270 reference regression is run under exact r13196; dev10 therefore treats candidate13 as the current source target, not as inherited runtime proof.


## dev11: candidate16 detached s3270 semantic evidence

dev11 advances the Terminal Machine consumer from the dev10 candidate13 pin to
current `oorexx_terminal_machine_v0.22-candidate16`.  PRE23 JES completion/spool
gating remains unchanged.

Candidate16 strengthens the independent s3270 reference oracle without changing
`TN3270LiveSession`.  It parses one complete `ReadBuffer(Ascii)` action response
(data records + the 12-field s3270 status + final completion), derives
rows/columns/cursor/keyboard from that same retained response, and compares
field geometry, field protection/numeric/MDT/NONDISPLAY state, SFE x41/x42/x43/x45
attributes and SA character-attribute runs.  NONDISPLAY display content remains
masked and DBCS remains fail-closed.

The MVS runner now retains that reference evidence explicitly:

- `x3270_tso_read_discovery.sh` can write the complete authenticated READY
  `ReadBuffer(Ascii)` response to `X3270_READBUFFER_RESPONSE`;
- `s3270_reference_discovery.rex` uses candidate16 `S3270ReferenceParser` to
  publish metadata-only reference facts (no display rows or secret contents);
- `run_dual_terminal_machine_tso_live.sh` runs Terminal Machine first, requires
  clean LOGOFF, then runs the s3270 reference sequentially on the same target/LU
  and retains both evidence planes separately;
- target separation checks now cover both Terminal Machine and s3270 evidence.

This does **not** relabel s3270 evidence as Terminal Machine evidence.  The
candidate16 differential algorithm remains Terminal Machine's qualification
mechanism; MVS Intention only retains the independent reference facts and raw
response needed to audit that comparison.
