# Alchemy Workflow v0.1-dev1

Architecture: Tom Dyer
Coding: Claude (Opus 5.5)
Written by: Claude (Opus 5.5), 11 Nov 2026

The workflow planner for the Alchemy build. A workflow is a list of stages. Steps are registered
into it, each one a small class in its own file. A rule book decides which steps apply to a package
and how strictly. Every run leaves a receipt. When the package fails, the task that submitted it is
sent a message saying what it did wrong.

The first workflow, `autobuild-shadow`, runs beside the Python Autobuild (v0.5.2) and stops
nothing. It reports what the Python Autobuild does not check, and what it gets wrong.

## Why ooRexx, and why objects

The Python Autobuild grew by layers that patch each other at load time:
- v0.4 assigns over v0.3's functions (`_v3.environment = environment`);
- v0.5.2 replaces v0.3's `extract()`.

There is no object to ask what the rules are. To copy its environment rules, Body Slam's kitrun had
to read three layers of source.

Here, each piece is an object that can be asked:
- a step answers `id`, `stage`, `describe`, `skipReason(ctx)` and `intends(ctx)`;
- every class answers `~module_version` and `~module_lastChanged`;
- the plan says what will run before anything runs.

## Commands

From the repository root:

```
. packages/alchemy_workflow_v0.1-dev1/bin/workflow_env.sh
rexx packages/alchemy_workflow_v0.1-dev1/bin/workflow.rex steps
rexx packages/alchemy_workflow_v0.1-dev1/bin/workflow.rex plan packages/alchemy_website_publisher_v0.4
rexx packages/alchemy_workflow_v0.1-dev1/bin/workflow.rex run packages/alchemy_website_publisher_v0.4 --db /tmp/est/estate.db --lane slam-450
rexx packages/alchemy_workflow_v0.1-dev1/bin/workflow.rex survey /tmp/packages.list --db /tmp/est/estate.db --quiet
```

`--db` is Body Slam's database of the estate. KitRun needs it, and is skipped without it. KitRun
also needs `REXXSQL_LIBDIR`, a directory holding `librexxsql.so`, set before sourcing
`workflow_env.sh`.

Exit codes:
- 0: PASS
- 1: WARN
- 3: FAIL
- 4: a step broke (ERROR)
- 2: usage

## The objects

| Object | What it is |
|---|---|
| `Workflow` | Stages: intake, inspect, normalise, stamp, qualify, publish, report. |
| `WorkflowStep` | The protocol each step follows. Steps are in `src/steps`, listed in `etc/steps.list`. |
| `WorkflowRuleBook` | `etc/house.rules`, plus `--rule` at the submission layer. |
| `WorkflowContext` | The package: its family, version, manifest, and its ooRexx files, each read once. |
| `WorkflowSource` | One file: its raw lines, and code lines with comments and strings blanked. Also its directives (with each method's body), and the literal traps. |
| `WorkflowPlan` | What would run, in which mode, decided by which rule. |
| `WorkflowStepResult` | PASS, FIXED, WARN, FAIL, SKIP or ERROR, with findings. |
| `WorkflowFinding` | Rule id, file:line, what was found, the fix, and the command that shows it again. |
| `WorkflowReceipt` | Every result, plus the tree SHA-256 and the rule book SHA-256. |
| `WorkflowLedger` | Each judgement, so an identical resubmission is answered from it rather than run again. |
| `WorkflowFailureReport` | The mailbox message, and its one-sentence nudge. |
| `WorkflowLog` | The running progress log, through ooRexx Logging v0.7. |
| `WorkflowHash` | SHA-256 through crypto v0.8.3 and the Foreign Runtime. |

ERROR means the step broke, not the package. The report says so and names the step's version, so a
defect in the tooling is never charged to the package's author.

## Rules: who decides

The rule book has five layers: house, area, family, package, submission. For each step, and for
each rule of a step, the highest layer that matches decides. Inside one layer, the last line decides.

The modes:
- a step: `enforce`, `report` (each FAIL becomes a WARN) or `off`;
- a single rule: `off` or `warn`;
- `FILES.EXCLUDE`: path prefixes that no step reads.

The receipt and the failure report name the rule line that decided. A relaxation therefore always
leads back to a written reason.

Shadow mode is four house lines saying `report`. Turning a step on for real means changing one line.

## Steps in v0.1-dev1

| Step | Stage | Rules |
|---|---|---|
| Manifest | intake | MF-MISSING, MF-PARSE, MF-SCHEMA, MF-NAME, MF-PUBLISH, MF-TESTS, MF-CWD, MF-PROGRAM, MF-PYTHON |
| HouseRules | inspect | HR-PRIVATE, HR-EXPOSE-FIRST, HR-RESULT, HR-PLUS-ZERO, HR-LITERAL-CALL, HR-LITERAL-HEX, HR-COMMENT, HR-INDEX-LOOP, HR-CREDITS |
| ModuleStamp | stamp | MS-MISSING, MS-VERSION, MS-DATE (reports only, for now) |
| KitRun | qualify | KR-NOT-FOUND, KR-MISSING, KR-INVALID, KR-ENV, KR-OLDER, KR-TWO (through Body Slam v0.2) |

Each step file explains its own rules in its header.

## Not in v0.1-dev1

- Fix mode. ModuleStamp writing the two constants, and the tidy-up steps, will make object-level
  edits through SSC, never text substitution. The fix each finding names is the edit a fix step
  will make.
- Posting to the mailbox. The report is written to `out/outbox`, and whoever runs the workflow
  posts it. An ooRexx mailbox client comes next.
- Steps as their own packages. They are separate files and classes now. Each will move to its own
  versioned package once the protocol has settled.
- Tests, Publish, SphereRegenerate and Notify stages taking over from the Python Autobuild.
