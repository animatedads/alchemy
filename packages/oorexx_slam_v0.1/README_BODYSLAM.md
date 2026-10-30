# Body Slam v0.1: how the estate hangs together

**Architecture:** Tom Dyer. Body Slam is a SLAM component that ingests the whole Alchemy estate for a project linkage analysis, using a temporary database.
**Coding:** Claude (Opus 5.5), 2026-10-29.
**Database:** SQLite through Rexx/SQL 2.6B3 (Mark Hessling), via `oorexx_rexxsql_backend_v0.1`.
**Checked against:** the rx2cpp compiler's `RxLexer` (vendored here, ChatGPT and Claude) and ooRexx 5.3.0 r13196 (Tom's build).

SLAM reads code into segments. Body Slam reads the links between files and projects:
- `::requires`
- class definitions and uses of `.Name`
- `SUBCLASS`, `MIXINCLASS` and `INHERIT`
- literal bus topics (`~publish`, `~subscribe`, `~emit`)
- the `DEPENDENCIES` files projects declare

The work is done in ooRexx collections and then written to one SQLite file, where SQL asks the questions. The file is temporary: each ingest makes it again, because the source is the truth and an index that is never rebuilt drifts.

| File | Role |
|---|---|
| `src/BodySlamScanner.cls` | One file in, link facts out. It removes comments (block comments nest, as in Rexx) and strings, then cuts each line into clauses at `;` |
| `src/BodySlam.cls` | Walks the estate, assigns projects and families, resolves requires as the interpreter does, labels each use, writes the database |
| `src/BodySlamReport.cls` | The questions, in SQL. Recursive SQL for blast radius, Tarjan's algorithm for cycles |
| `bin/bodyslam.rex` | `ingest DB ROOT`, `report DB NAME... [N]`, `blast DB TARGET [N]` |
| `tests/test_bodyslam.rex` | 62 checks: each label, then the interpreter run that proves it; the scanner against RxLexer on real files |

## The rules, measured on ooRexx 5.3.0 r13196 (not taken from memory)

- `::requires` searches the requiring file's own directory first, then the current directory, then `REXX_PATH`, then `PATH`. A relative name is relative to the requiring file.
- Names are case-sensitive on Linux.
- A name with no extension tries `NAME.cls`, then `NAME.rex`, then `NAME`.
- The packages shipped with ooRexx (`json.cls`, `socket.cls`, `csvStream.cls`, ...) are in the interpreter's own directory, which is found through `PATH`. So an estate copy on `REXX_PATH` replaces the shipped one.
- A public class is seen through any chain of requires. A class that is not public is not seen. A package does not see its sibling packages' classes, even when the same parent requires both.
- `::requires (expr)` is refused: Error 19.904.
- `::class M mixinclass public` reads `public` as the name of a superclass.

Every rule above is also a run in `tests/test_bodyslam.rex`.

## Labels

**Requires**

| Label | Meaning |
|---|---|
| `LOCAL` | Found from the requiring file's directory. This is what the interpreter loads, always |
| `PROJECT` | Found once in the same project |
| `ESTATE` | Found once in the estate, in another project. Right only if `REXX_PATH` names it |
| `AMBIGUOUS` | Found more than once. `REXX_PATH` order picks which copy loads |
| `SYSTEM` | Shipped with ooRexx and not in the estate |
| `CASE_ONLY` | Found only with other letter case, so it fails on Linux |
| `MISSING` | Not in the estate and not shipped |
| `LIBRARY` | A native library |
| `INVALID` | Not a string or symbol. ooRexx refuses it |

**Uses of `.Name`**

| Label | Meaning |
|---|---|
| `SELF` | Defined in the same file |
| `REQUIRED` | Defined public in a file the requires reach |
| `NOT_PUBLIC` | Reached, but the class is not public, so it fails |
| `UNDECLARED` | Defined in the estate, but no require reaches it. A hidden link |
| `BEHIND_MISSING` | As `UNDECLARED`, but a require on the way is `MISSING` |
| `BUILTIN` | An ooRexx class or environment entry |
| `UNKNOWN` | None of the above |

**Strength of a link**
- **DEFINITE:** `LOCAL`, `PROJECT` and `ESTATE` requires. Each can be only one file.
- **POSSIBLE:** also every candidate of an `AMBIGUOUS` require.

A project is the first two path parts (`packages/alchemy_objects_v0.8`). Its family is the name before `_vN` or `-vN` (`alchemy_objects`).

## The estate (animatedads/alchemy `ce70c323`, 2026-10-29)

25,778 files, of which 9,717 are ooRexx (1,347,797 lines), in 646 projects and 459 families. The ingest takes 3 min 24 s (94 s reading, 110 s writing) and makes a 15 MB database. For comparison, SLAM's segment ingest of the same estate takes about 30 minutes. Body Slam reads only the link facts, so it does not need the full lexer; the scanner agrees with RxLexer on 1,220 of 1,220 sampled files (every 7th file; 1,819 requires, 2,475 classes, 9,829 uses).

**Requires (14,399):**

| Label | Count |
|---|---|
| PROJECT | 6,705 |
| LOCAL | 4,942 |
| AMBIGUOUS | 1,351 |
| ESTATE | 1,063 |
| MISSING | 141 |
| LIBRARY | 98 |
| SYSTEM | 86 |
| INVALID | 12 |
| CASE_ONLY | 1 |

**Uses:**

| Label | Count |
|---|---|
| REQUIRED | 43,831 |
| SELF | 12,753 |
| UNKNOWN | 516 |
| BEHIND_MISSING | 206 |
| UNDECLARED | 132 |
| NOT_PUBLIC | 6 |

## Finds, each checked by hand or by running it (credited to Body Slam, SLAM's component)

1. **`brand_narrative_directive_v0.1-dev4` cannot load.**
   - Body Slam's undeclared report lists `.AlchemyObject` at `src/BrandNarrativeDirectiveCore.cls:111`, with no require that reaches it.
   - Run: the package's own `tests/compile_smoke.rex` stops at exactly that line, with Error 98.909 `Class "ALCHEMYOBJECT" not found`. It does this even with `alchemy_objects_v0.8/src` on `REXX_PATH`.
   - The same package's `BrandNarrativeDirectiveModel.cls:37` uses `.BrandNarrativeDirectiveConstant`. That class is defined in its sibling `Core.cls`, which `Model.cls` never requires, and a sibling's classes are not seen (measured).
2. **`ReportMathsMixin` and `ReportCryptoCheckMixin` (`alchemy_report_v0.1`) are not public.**
   - `::class ReportMathsMixin mixinclass public` makes `public` the superclass name.
   - Separately, the package does not load: `src/AlchemyReport.cls:162` has `use arg` before `expose`, which is a translation error (Error 99). That breaks the house rule that `expose` comes first.
3. **12 requires ooRexx refuses** (`::requires (lib)` / `(root1)`).
   - Files: `operationalctl.rex`, `servicectl.rex` and `storagefetchctl.rex`, in `oorexx_operational_degradation_planner_v0.1-dev3`, `oorexx_storage_fabric_v0.1-dev23` and the copies vendored from them.
   - Run: Error 19.904. These programs cannot start.
4. **`federationbank_teller_cash_service_v0.1` cannot run from this repository.**
   - Its chain requires `FederationBankTellerTillService.cls`, which is MISSING from the repo.
   - Run: Error 43.901 for that file, with every Federation Bank source directory on `REXX_PATH`.
   - Its `.FederationBankTellerTill` uses are labelled `BEHIND_MISSING`. The label was added after this case, because without it the uses read as a hidden link.
5. **MISSING:**
   - 12 requires of `ObjectQueueXTPTransport.cls` (ChatGPT's ed209 RTO2 candidate in `autobuild/inbox`, and four more projects).
   - `Protobuf.cls` (the gRPC binding examples).
   - `RTO2CountJob.cls`, `AlchemyRTO.cls` and 66 more distinct names (141 requires in all).
6. **`oorexx_queue_fabric_v0.9-dev4`** is declared 17 times in `DEPENDENCIES` files and is not in the repository; the versions here are 0.9-dev5, 0.9-dev6 and unversioned. In all, 102 declarations name 60 distinct package versions that are not here. This is the gap SLAM's `run_tests.sh` had to work round by hand for the bank engine.
7. **`Crypto.cls` is required as `Crypto.cls` but the file is `crypto.cls`** (`examples/regulated_intermediary_distribution_v0.8-dev4/src/RIDWireAuthority.cls:88`). This fails on Linux.
8. **Version shadowing by name.**
   - `crypto.cls` (65 requires) can load from 13 copies in 7 families.
   - `AlchemyObject.cls` (77) from 10 copies in 5 families.
   - `TestSupport.cls` from 36 different families' test supports.
   - `json.cls` (267 requires) can load an estate copy in place of ooRexx's own. Both copies are byte-identical to the shipped 5.3.0 file today, so this is harmless until one changes.
9. **Six family cycles**, for example:
   - `wire_ui_builder` ↔ `wire_ui_server`
   - `civicport` → `federationbank_engine` → `oorexx_jms_queue_bridge` → `civicport`
   - four instrumentation/intention families in one ring
   - `oorexx_maths` ↔ `oorexx_physics_world`, where the maths side is a benchmark file, `benchmarks/benchmark_physics_dev43_guitar_dynamics.rex:105`

**Hubs** (DEFINITE; families that require each one):

| Family | Families using it | Requires into it |
|---|---|---|
| `runtime_registry` | 23 | 99 |
| `oorexx_socket_provider` | 18 | 142 |
| `alchemy_objects` | 18 | 55 |
| `oorexx_intention_service` | 15 | 54 |
| `institutional_policy` | 15 | 29 |

**Blast radius of class `AlchemyObject`:** 324 files in 34 projects DEFINITE, 3,211 files in 179 projects POSSIBLE. The gap is the ambiguous names: `REXX_PATH` order decides which copy each program loads.

## Run

```sh
rexx bin/bodyslam.rex ingest /tmp/bodyslam.db ../..
rexx bin/bodyslam.rex report /tmp/bodyslam.db all 15
rexx bin/bodyslam.rex blast /tmp/bodyslam.db AlchemyObject
rexx tests/test_bodyslam.rex "/tmp/bs|../..|7"
```

Each needs `librexxsql.so` on `LD_LIBRARY_PATH` and `REXX_PATH` set as in `run_tests.sh`. Report names:

| Name | Shows |
|---|---|
| `summary` | counts by label |
| `ambiguous` | names that can load more than one file |
| `clashes` | ambiguous names whose candidates are in different families |
| `missing` | requires not in the estate and not shipped |
| `shadows` | estate copies of names shipped with ooRexx |
| `invalid` | requires ooRexx refuses |
| `caseonly` | requires that match only with other letter case |
| `duplicates` | public class names defined in more than one family |
| `undeclared` | uses no require reaches |
| `notpublic` | uses of classes that are not public |
| `edges` | family-to-family requires |
| `hubs` | families required by the most other families |
| `cycles` | families that require each other |
| `topics` | literal topics with no subscriber or no publisher, and topics that join two families |
| `declared` | declared dependencies not here, and requires not declared |

## Not in v0.1 (stated, not hidden)

- **Start-up is not read.** `PROJECT`, `ESTATE` and `AMBIGUOUS` say where a file *could* load from. The `REXX_PATH` that each `run_tests.sh` builds would turn most of them into one answer. That is the next step.
- **No file roles.** A test or benchmark edge counts the same as a source edge; the maths ↔ physics cycle shows why that matters.
- **Topics are literals only,** and `~publish` is not one API. `InstrumentationMesh~publish` takes a time first, so `2026-10-08T10:05:00Z` appears as a topic.
- **`.environment~setEntry` and `.local[...]` entries are not read,** so some UNKNOWN uses are entries a program sets itself.
- **A clause continued with a trailing comma is read as two clauses.**
- **Java, C++, NetRexx and Python files are indexed but not read for links.** SLAM's readers for the first three could supply them.
- **Body Slam's facts are not yet in SLAM's store as nodes,** so SLAM's Task cannot yet path-search across projects. The family edges, with counts as priors, are ready for that.
- **No README in SLAM's closed vocabulary yet.**
