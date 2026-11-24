# newshell_llm v0.1-dev6 — Codex as a principal on an MU; fixes from cats1's first readings

Architecture: Tom Dyer (24 November 2026). Coding: Claude (Opus 5.5); `Computer.cls` v0.1 and the first `ShellObject` by ChatGPT.

```
start llm claude
proto fs build/proto_tom
provide llm claude the fs
prompt claude "find largest file"
proposal
~run
```

`prompt` returns a **Proposal**. It runs nothing. Only `~run` executes the code, and the result is a ShellCollection, so `~~table` and `~~json` work on it.

## dev6: what cats1 showed (24 November 2026)

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). The dev5 kit went onto cats1 (REQ-00005567, approved by Tom), and its self-test passed there with real readings. Codex's first job through newshell (`return mu~audit~findings`, run as principal codex) and a raw `nft list set` confirmed two faults, both fixed here:

- **The audit saw its own invoker.** Inside the self-test (run under sudo) the MU audit reported `EXTRA process sudo`; the plain audit, without sudo, was THIN. `MuAuditor` now marks a process finding INVOKER when every process with that name is an ancestor of the audit itself, such as sudo or the ssh session's shell. INVOKER rows are listed but do not count against `thin` (`invokerOnly` counts them). If the same name is also running anywhere else, the finding stays EXTRA. The test uses a stub audit: rexx becomes INVOKER, ghostproc stays EXTRA.
- **A set's elements wrapped onto a second line were lost.** nft printed `elements = { 20.0.154.12, 20.118.224.14,` then `80.240.21.156 }` on the next line, and dev5 kept two. The reader now gathers them up to the `}`. Sets gain `elementCount` and `elementList`. The fixture now wraps exactly as cats1's nft does.
- **Tables cut long text from the wrong end.** Cells are now up to 72 characters. A path keeps its tail; any other text, such as a firewall rule or a verdict, keeps its start.
- **Self-test.** It now also prints the audit's findings, not just their count.

**Also from cats1** (no code change): listening tcp 22 and udp 68 only; mu_fence input policy drop, output policy accept; output allows DNS to 168.63.129.16 and drops everything else to it; routes to 168.63.129.16/32 and 169.254.169.254/32 via 172.16.0.1; no failed units; xtpd installed and not running; `bringUp` refused.

**Order mistake (mine):** `pgrep -af PATTERN` run through `sshnode.sh` matches its own `bash -c` command line. I wrote it twice (xtpd step 8, newshell N5), and Codex stopped both times. Use `pgrep -af "[x]tpd.rex"`: the brackets stop the pattern matching itself.

## dev5: Codex as a principal, and objects for an MU (24 November 2026)

Architecture: Tom Dyer. Put newshell on ed209g (cats1) and hand Codex the keys. It works through shell objects to start an MU and examine networks; its plans report back to it; the policy decides every protected call. Coding: Claude (Opus 5.5).

**Agent entry (`bin/nsh-agent.rex`, the kit's `/opt/newshell/bin/nsh-agent`).** One command per invocation, as Codex works over `sshnode.sh`:
```
nsh-agent describe                    the objects: the same brief an LLM is given
nsh-agent check FILE                  the check, and the source of every method FILE calls
nsh-agent run FILE [--follows JOB] [--wait S]   run as the principal; wait; print each job's report
nsh-agent jobs | report JOB           the jobs kept in the state directory
```
- **Output and exits.** stdout is what the agent reads; progress goes to stderr. Exit 0 means ok, 1 a job FAILED or DIED, 2 rejected, refused or error.
- **Job store.** A settled job is kept as JSON in the state directory, and every invocation reads them back. So `jobs~find(name)`, `amend` and the History work across separate commands: the killed-compile chain passes as five separate processes (`test_agent.rex`).
- **Principals.** `Agent` is a `ShellContext` with no LLM client, principal `codex`. Plan steps now run as their owner's principal: dev4 hard-coded `llm`, which the per-principal policy caught.
- **Split.** `ShellProposal.cls`: `ShellContext`, Proposal, ProposalCheck and the source cache moved out of `ShellLlm.cls`, so a node needs no Anthropic client.

**Objects (read-only unless marked):**
- `Network` (`ShellNet.cls`):
  - `interfaces`, from /sys/class/net;
  - `addresses`, from `ip -j`, else /proc;
  - `routes`, from /proc/net/route and ipv6_route;
  - `listening`, from /proc/net/tcp, tcp6, udp, udp6;
  - `firewall`, from `nft -a list ruleset` (root): rules (with handles; a kept rule is current only while its handle holds the same rule), sets (`xtp_peers` and its elements), chains (hook, policy).
- `Services` (`ShellHost.cls`): `units`, `failed`, `enabled` (systemctl).
- `MuAuditor`: the estate's MU audit (`/opt/mu-tools/src/NewShellMuAudit.cls`), loaded at run time, so newshell does not ship it. It gives findings, thin and error.
- `Xtpd`: installed, running, pids, socket, config, listens, `logTail`. `bringUp(config)` and `bringDown` are protected. They are not named start/stop because `~start` is ooRexx's asynchronous send, which the check refuses.
- `Mu`: hostname, kernel, uptime, boot id, plus `net`, `services`, `audit`, `xtpd`.

**cats1 (`etc/cats1.policy`, `etc/agent.conf`).**
- **Your standing rule as deny lines:** firewall, keys, forwarder, reboot, and `run:nft`/`iptables`/`ssh-keygen`/`systemctl`/`reboot`/`shutdown`, for every principal.
- **Xtpd:** denied until you add an allow line.
- **Codex:** may only submit jobs and remove files in `/var/lib/newshell/work`.
- **Contract:** the cats contract forbids build tools, so the compile chain is a demonstration here, not a cats1 job.

**Kit:** `newshell-kit-v0.1-dev5-jammy.tar.gz`, sha256 `ad6207e3830f847d64873c6f89a2b92d7e5f2219c3f1d81b8b0983adda094c33`, built in the jammy chroot by `build_newshell_kit.sh`.
- **Contents:** newshell (no ShellLlm), oorexx_process dev2 with its native library built against 5.3.0, LoggingCore, MethodInterposition, crypto. No package from the contract's forbidden list.
- **`tests/kit_selftest.sh`:** read-only, with a temporary state and config. It covers describe, `mu`, the network objects, the fence, failed units, the MU audit and xtpd. It also checks that `bringUp` is refused and that a command is rejected before it runs. Rehearsed in the chroot: KIT_OK, LDD clean, PASS.

**Found:**
- **Steps ran as `llm` whatever the owner.** Caught by the cats1 test policy.
- **`--follows` took one word** of a job name.
- **The CLI called every error REFUSED.** Now only 98.948 is REFUSED; anything else is ERROR.
- **`File` objects sorted with a string comparator** (`interfaces`).
- **A label inside a loop** (the job-store parse); moved into a routine.
- **The kit manifest listed itself.** `find` ran after the shell had created the file; it is now excluded. Kit r2 was checked and is clean.
- **mu-tools `HostCommand`.** When a command is missing (rc 127, e.g. no `dpkg-query`), its error path fails with "does not understand RC" and the whole audit aborts. On cats1 every command exists, and the audit was THIN there. `MuAuditor` reports such a failure in `error` instead of crashing.

**Not in dev5:** reports to Codex through the Rasen Falcon mailbox (it reads them from `run`'s output); an xtpd STATUS over the control socket; MU start beyond xtpd (MIs, mu-agent).

## dev4: a compile that dies, and the chain that recovers it (24 November 2026)

Architecture: Tom Dyer. The job is unzip, compile, test run. Mid-compile, `killall -9 make`. The plan detects that the step died and tells the LLM. The LLM plans a review of the wreckage, then a cleanup, then amends the plan with a fix and runs the new plan. Coding: Claude (Opus 5.5).

```
prompt claude "unzip hello.zip, compile it with make in the hello directory, then test run ./hello/hello and check it prints Hello"
autopilot 5
~run
'(sleep 1.2; killall -9 make) >/dev/null 2>&1 &'
wait 200
```

**Live (Haiku 5.5, every step chosen by Claude; 10 calls, $0.0032):**

| job | state | what Claude said |
|---|---|---|
| build-and-test-hello | DIED at 2/3 make | "make was SIGKILLed mid-build and left build.lock behind" |
| review-make-killed | PASSED | looked only: `ws~list('hello')`, tail of both make logs |
| clean-stale-build-lock | PASSED | removed `hello/build.lock`, `fileAbsent` confirmed it |
| build-and-test-hello-retry | PASSED 4/4 | `jobs~find` + `amend` + `insertStep(2, 'remove-stale-lock')` |
| (follow-up) | `return .nil` | "Nothing is left to fix; no new job is submitted." |

**What dev4 adds:**
- **DIED.** A program killed by a signal is `DIED`, not FAILED (RunResult `killedBy`, exit 128+n), and the plan always stops there. When stderr is empty, the report shows the end of stdout: what the program was doing when it died (here `sleep 3`).
- **Every notification gets a follow-up.** The LLM no longer replies with a paragraph: it writes the next proposal, which goes through the same draft, source review and check. Its leading comment is the diagnosis. The instructions are: review if something DIED or the cause is unclear; clean up what a review showed; amend the original plan once the workspace is clean; return .nil if nothing needs doing; never repeat a review.
- **History.** A plan submitted by a follow-up remembers the job it follows (`origin`), and each report starts with that history. `jobs~find(name)` gets any earlier job, so the original can be amended.
- **Plan editing:** `amend(newName)` (copies, leaving the original alone), `insertStep(at, name)`, `removeStep(at)`, `stepNamed(name)`, `stepAt(at)`.
- **Look-only workspace methods:** `ws~list(dir)`, `ws~tail(file, n)`. And `ws~remove(file)`, which is protected (`allow llm Workspace remove /tmp`).
- **Confinement.** `ws~run` arguments that are paths, and every `list`/`tail`/`remove` path, must stay inside the workspace and not pass through a link (`make -C /etc`, `remove ../x`, `tail /etc/passwd` are all refused).
- **`autopilot N`** (console): runs up to N checked follow-ups as they arrive. The policy still decides every call, and a REJECTED follow-up is never run.

**Found live, each an API trap Claude walked into, each fixed:**
1. An empty log printed nothing, so Claude decided the logs could not be read and reviewed three times. Empty findings now say "empty: 0 lines", log paths are relative and ready for `ws~tail`, and a repeat review is discouraged.
2. `insertStep(1)` then `stepAt(2)` hit the wrong step; `stepNamed` was added.
3. `passIf('exitIs', 0)` on `ws~remove` failed with "no program ran". For an action that is not a program, exitIs 0 now means it completed.
4. `outputHas` on a `ws~list` result had "no output to check". It now reads the text of any result.
5. There was no way to say "the file is gone": `fileAbsent` added.
6. A plan with a failed `onFail('continue')` step reported PASSED. It now ends FAILED; continue only means the later steps still run.
- Also found: make's orphaned `sleep 3` held the output pipe, so the runner returned 1.8 s after make died. The step's time is the time until the pipe closed, not the moment of death.

**Not in dev4:** finding and killing orphaned children of a died step (here the `sleep 3`); a budget per chain rather than per console session; restarting from a step instead of amending.

## dev3: plans and watches that report back (24 November 2026)

Architecture: Tom Dyer. The LLM registers a multi-step plan object, and each step carries its checks and its pass/fail criteria. The plan runs without the LLM watching it. When it stops, the LLM is sent the job, the stage reached, and that stage's result: the error point with a trace, not the full build output. Trigger events (disk space below n, a log file appearing) work the same way. Coding: Claude (Opus 5.5).

```
mount ws /tmp/nsjobs
start llm claude                      (also creates jobs, Claude's job board, and provides it)
provide llm claude the ws
prompt claude "unzip hello.zip, compile it with make in the hello directory, then check it worked"
~run                                  (registers and submits the plan; returns at once)
wait 90                               (the console waits; the LLM does not)
inbox
```

- **`JobBoard`** (`jobs`): `plan(name)`, `watch(kind, ...)`, and `submit(job)`. `submit` is protected, so the policy decides (`allow llm JobBoard submit *`). It starts the job on its own thread and returns.
- **`Plan` / `PlanStep`:**
  - `step(name)~does(target, method, args)~passIf(kind, value)~onFail('stop'|'continue')~timeout(s)`;
  - check kinds: `exitIs`, `fileExists` (a file or a directory), `outputHas`, `outputLacks`;
  - each step's action runs through a routine under the security manager as `llm`, so `ws~run` is authorised per program: `Workspace~run` is judged as `run:PROGRAM` against the workspace path (`allow llm Workspace run:make /tmp`; `run:./*` is any program inside the workspace).
- **`Workspace`** runs programs through oorexx_process dev2: an argument list, no shell, a timeout, output captured to `.newshell/runs/NNN-program.out/.err`. It returns a `RunResult`.
- **`atError`** is the `StepOutcome` where the plan stopped. Its `errorReport` gives the program and its exit status, plus the first line matching an error pattern, three lines before it and six after, with that line marked. It also gives the paths to the full logs.
- **The message to the LLM** is the plan's `report`. In the live run it was 913 characters, against 203 lines of build output on stdout. The model replies in at most four lines, and that diagnosis is kept on the plan (`plan~diagnosis`) and shown in the inbox. PASSED plans go to the inbox only, unless `claude~notifyOnPass(.true)`.
- **`Watch`:**
  - `diskFreeBelow(path, bytes)`, which uses `df -P -B1` through oorexx_process because ooRexx has no statvfs on Linux;
  - `fileAppears(dir, pattern)`, with `*` and `?`;
  - `every(s)` and `lasting(s)`; each watch fires once, and when it fires the LLM is told.
- **"Settled"** means the state is final, the owner has been told and the inbox has been posted. `wait` uses it.
- **No way round `submit`:** `~launch`, `~execute` and `~poll` are protected, and the lint rejects them in proposals.

**Live (Haiku 5.5):**
1. Claude wrote a 3-step plan, which was submitted. It failed at step 2, compile, with the error at `hello.c:3:34: error: expected ';' before 'return'`. Claude's diagnosis: hello.c line 3 is missing its terminating semicolon after printf; add it and rerun from step 2.
2. On the fixed zip, the plan PASSED: inbox only, no LLM call.
3. "Tell me when a .log file appears" became a `fileAppears` watch, which fired on `build.log`, and Claude was told.
4. In total: 8 LLM calls, $0.0012.

**Found:**
- **Guarded loops.** The plan and watch loops were guarded methods, so a long `poll` held the object's lock and `~~table` on an armed watch hung the console. They are now unguarded; they are the only writers of their state.
- **`fileExists`.** Claude used `fileExists` for a directory on its first live plan; it now means the path exists.
- **P9 in my own code.** A variable named `result` in `PlanStep~perform` emptied the error report. It was caught by the tests, renamed, and is now a pre-check in `run_tests.sh`.
- **P7 twice more** (`call .X~y`, `call x~y`). It is now a pre-check too, so the tests refuse to run until it's fixed.
- **ShellCollection tables** now take mixed rows (plans and watches together).

**Not in dev3:** restarting a plan from a given step; persisting the inbox; sending messages back through the Rasen Falcon mailbox instead of the in-process inbox.

## dev2: the security manager authorises (24 November 2026)

Architecture: Tom Dyer. Proposals run under the security manager, and the security manager performs the authorisation. Whether `~edit` is permitted is decided from the object's path. Coding: Claude (Opus 5.5).

```
create file "/tmp/test.txt"
fsobj~edit~addLine("test 1234")
```

- **Protected methods** are the only way to change anything: `FileSystem~create`, `FsFile~edit`, `FileEditor~addLine`. Each object says which path governs a call (`authorityPath`). ooRexx's own security manager (`Routine~setSecurityManager`) gets a METHOD message for every protected call made from secured code. `ShellSecurityManager` looks up the policy and allows the call, or raises 98.948.
- **Policy:** `etc/newshell.policy` (or `NEWSHELL_POLICY`). Each line is `verdict principal class method path`. The first matching line wins, no match denies, and a path matches itself and everything below it on `/` boundaries. A path that passes through a symbolic link is denied before any rule is read. `policy` shows the rules.
- **Principals:** `llm` for a proposal under `~run`; `console` for every line a person types at nsh. Each console line runs as its own secured routine, with variables carried between lines, so the same policy binds the person too.
- **The other security manager messages:**
  - for `llm`: COMMAND, CALL (external), STREAM and REQUIRES are denied, and only ARRAY, SHELLCOLLECTION, TRUE, FALSE, NIL and ENDOFLINE are allowed as dot names;
  - for `console`: all of these are allowed, and each one gets a receipt.
- **Receipts:** every decision is a `ShellDecision` (verdict, principal, kind, target, path, rule). `decisions` (or `proposal~decisions~~table`) shows the last run's, and each one is also logged as `AUTH ...` through oorexx_logging.
- **Trusted code is not checked:** the manager covers only the code it is attached to. The shell's classes do the I/O; the proposal only asks.
- **The objects keep their own limits:** nothing outside the FileSystem root, never writing through a link, walks never following links.

**Found:** the security manager does not see built-in classes (`.File`, `.Stream`) or `value(name,, 'ENVIRONMENT')`. ProposalCheck still rejects those, so the lint stays.

**Live (Haiku 5.5, default policy):**
- "create file /tmp/test.txt, then add the line test 1234" was proposed, checked against 3 method sources, run, and allowed by rules 9, 10 and 11. The file holds `test 1234`.
- The same task for `/home/claude/newshell_test.txt` was denied by rule 13 at `FileSystem~create`, and nothing was created.
- Typed by hand at nsh: `/tmp` was allowed by rule 12, and `/home/claude` was denied by rule 13.

**Not in dev2:** a time limit on `~run`; an owner/mode check on the policy file (it refuses symlinks only); a separate read-only way to read a file's lines (`~lines` currently goes through `~edit`).

## How a prompt goes

1. **Round 1, draft.** The system prompt describes each provided object from its own class: fields, public methods, capabilities, and the class's `SHELL_HELP` note. It also describes one item of anything you can `DO OVER`. It carries `cache_control`, so later calls read it from the API's prompt cache (643–675 tokens in the live run).
2. **Round 2, review against source.** The shell finds every `~method` the draft sends. It reads each method's source from the live object (`instanceMethod(...)~source`) through `MethodSourceCache`, and sends those sources back. It also names any method that no provided object or built-in class has. The model replies with its final code.
3. **Check.** `ProposalCheck` rejects:
   - ADDRESS, CALL, INTERPRET, SIGNAL, PULL and directives;
   - stream functions, VALUE() and Sys* functions;
   - dot names other than `.Array` and `.ShellCollection`;
   - reflection (`~class`, `~send`, `~setMethod`, ...);
   - RESULT, RC or SIGL as variables;
   - calls to unknown methods.
4. **Round 3, repair (once).** If the check rejects the code, its problems go back to the model one time.
5. **`~run`.** First it confirms that every method source checked in round 2 is unchanged (the cache entry holds the text and a SHA-512 digest). Then it runs the code as a routine under `ADDRESS NEWSHELL_NONE`, so a command string returns rc 30 and does not execute.

## Where the limits are

1. The objects are read-only. FileSystem/FsFile have no method that changes anything, and links are never followed.
2. Nothing runs until a person sends `~run`.
3. `ADDRESS NEWSHELL_NONE`.
4. The check, which is a lint, not a sandbox.
5. Refusal when a checked source has changed.

Not in dev1: a time limit on `~run` (a `do forever` would hang the console).

## Key handling

The Anthropic key is read from `ANTHROPIC_API_KEY` by `oorexx_secret_broker` (MappedEnvironmentSecretProvider). It reaches curl only on stdin (oorexx_ai_provider_anthropic v0.5 discipline). It is never on argv or disk, and never in the log.

## Estate parts

- oorexx_ai_provider_anthropic v0.5
- oorexx_ai_access v0.6
- alchemy_objects v0.8
- oorexx_secret_broker v0.2
- oorexx_crypto v0.1 (SHA-512)
- oorexx_logging v0.7 (progress on stderr as `[newshell] ...`, receipts in `NEWSHELL_LOG`)

## Files

- `src/ShellObject.cls`: the common contract. Adds `describe`, ShellCollection `sortedBy`/`first`/`select`, and the ScratchPad.
- `src/FileSystem.cls`: FileSystem and FsFile, read-only.
- `src/ShellLlm.cls`: Llm (dev5: a ShellContext; needs the Anthropic packages).
- `src/ShellProposal.cls`: ShellContext, Proposal, ProposalCheck, MethodSourceCache, MethodSource (dev5).
- `src/ShellAgent.cls`: Agent, JobStore (dev5). `src/ShellNet.cls`: Network, Firewall (dev5). `src/ShellHost.cls`: Mu, Services, MuAuditor, Xtpd (dev5).
- `bin/nsh-agent.rex`: the agent entry (dev5). `etc/cats1.policy`, `etc/agent.conf`: cats1 (dev5).
- `src/ShellSecurity.cls`: ShellPolicy, ShellPolicyRule, ShellDecision, ShellSecurityManager (dev2).
- `src/ShellLog.cls`: NewshellLog over oorexx_logging.
- `src/ShellJobs.cls`: JobBoard, Plan, PlanStep, StepCheck, StepOutcome, Workspace, RunResult, ErrorPoint, Watch, ShellInbox (dev3).
- `bin/nsh.sh`: the console launcher (needs `build/env.sh` from `tests/run_tests.sh`).
- `etc/newshell.policy`: the default policy (dev2).
- `src/Computer.cls`: v0.2 (processes with pid+starttime identity).
- `bin/nsh.rex`: the console verbs.
- `tests/`: `test_agent.rex` (dev5: Codex across processes, objects, refusals), `kit_selftest.sh` (dev5: on the node), `test_died.rex` (dev4: the killed compile and the whole recovery chain, offline), `run_tests.sh` (builds the oorexx_process native from source; P7/P9 pre-checks), `test_jobs.rex` and `make_hello_zip.rex` (dev3), `test_security.rex` (dev2, no network), `test_offline.rex` (fake curl, no network), `test_live.rex` (needs the key), `make_proto_fs.rex`.

## Findings

- **ooRexx: a variable named `result` is clobbered** by any message instruction (`x~append(y)` sets RESULT). This came from Haiku's first live proposal; the list came back as `ShellCollection(1)`. Now a check rule, a system-prompt rule, and a guard in ShellCollection~new. Pitfall candidate P9.
- **`/proc` files report size 0**, so `lines()` says 0. Pitfall candidate P8 (Computer.cls).
- **`call .X~y(...)` written a third time** (make_proto_fs.rex). P7 needs to become a real lint rule.
- `MutableBuffer~append(a, b)` joins without spaces; use `a b` in one argument.

## dev7, part 1 (24 Nov 2026): native providers underneath, the editor as a shell object

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Native providers: ChatGPT
(newshell_native_providers v0.1-dev10, published 9f1a714c, the agreed integration point).
Source editor: oorexx_source_editor v0.1-dev9 (dev1-dev8 ChatGPT, dev9 Claude) over
oorexx_atomic_file v0.1-dev1.

- **ShellNative** (new) loads the providers at run time, once. Mode `native` when they load
  (ooRexx 5.3 with librxshellposix), `rexx` otherwise, with the reason (`whyNot`).
  `NEWSHELL_NATIVE=off` forces plain Rexx. Nothing here is a shell object; proposals cannot
  name these classes.
- **LinuxProcess~rssKiB** uses the real page size (sysconf through the provider, else the
  kernel's KernelPageSize in /proc/self/smaps). ChatGPT found the 4 KiB assumption.
  `LinuxProcess~pageSizeAware` (class method) tells its override to step aside.
- **FsFile**: with the provider, one stat that never follows a link gives device, inode,
  `mode` (octal, e.g. 0640), uid, size and nanosecond mtime; `identity` carries
  device:inode, so a file replaced by rename is a different file and `isCurrent` says so.
- **FsFolder** (new, Tom's naming rule: no shell class takes an ooRexx built-in name): a
  folder. `d~entries(n)`, `d~files`, `d~folders` list its own entries, at most 2000. With
  the provider they come from a pinned directory read in bounded batches and closed on
  every path. `fs~folder(path)`, `fs~folders` (`fs~directories` kept for old proposals).
- **diskFreeBelow** reads free bytes through statvfs (the provider pins the path); `df`
  only without it.
- **SourceFile** (new, src/ShellSource.cls): `f~openSource`.
  - Open (no grant needed): `line`, `lines(first, last)`, `lineCount`, `find`, `grep`
    (rxregexp: `?` is any one character), `lint` (P1-P4, P7, P9), `check` (compiles?
    code and line).
  - PROTECTED, in memory until save: `replaceLine`, `insertBefore`, `insertAfter`,
    `amend(first, last, text)` (returns the replaced lines).
  - PROTECTED: `save`, the single write. It goes through the editor's saveChecked, which
    refuses if the file changed on disk, and refuses an ooRexx edit that stops a compiling
    file compiling.
  - Every protected call is judged on the file's path. etc/newshell.policy lets llm
    amend and save under /tmp. The editor loads when first used, so a kit without it
    keeps every other file object.
- **Tests**: tests/test_dev7.rex runs in both modes.
  - Native (ooRexx 5.3, Ubuntu 22.04 build system): page size; FsFolder entries (the link
    listed, not followed); mode 0640; inode identity changes when a file is replaced by
    rename; statvfs free bytes.
  - As llm under a policy for notes/ only: read, find, grep, lint (P7), check (a syntax
    error reported on line 2); amend and save allowed in notes/; refused in logs/;
    the save of a breaking edit refused and nothing written.
  - Plain Rexx (ooRexx 5.2): the same checks without the native ones.
  - Every dev6 suite still passes in both.
- **Not in this part**: the cats1 kit is still dev6 (tests/build_newshell_kit.sh
  unchanged); pidfd orphan cleanup, inotify and timers under the job board, Archive, Lock,
  nft -j, the RTO2 plan round trip and the Auth come next.
