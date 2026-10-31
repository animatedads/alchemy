# Piledriver v0.1: logs, tables and sheets, with no model

**Architecture:** Tom Dyer. Piledriver is the SLAM component that understands CSV files, log files and spreadsheets: functions, values, errors, rows and columns. Tom's brief keeps two questions apart: *is this an error code?* and *have I seen this pattern before in this file?*
**Coding:** Claude (Opus 5.5), 2026-10-30.
**This README:** Claude (Opus 5.5).
**Reading tables:** `csvStream.cls`, shipped with ooRexx 5.3.0 (Rexx Language Association).
**Checked against:** real files from the Alchemy estate (listed below), ooRexx 5.3.0 r13196's own error output, and hand-typed samples of syslog, log4j, Python logging and Apache access logs.

Gemini's estimate was that a model needs about 0.5 billion parameters to read the header of a CSV file, work out its tables and read an error file. Piledriver does it with none. Every decision is a closed list, a shape or a count, and each record says which one decided it. `tests/test_piledriver.rex` has 101 checks, and all 101 pass.

## Three questions, asked in order

**1. What kind of file is this?** (`PiledriverSource`) It is asked once, before any line is judged, because an error means a different thing in each kind of file.

| Kind | What an error is there | Read by |
|---|---|---|
| XLSX, ODS | A value *type* in a cell (`#DIV/0!`), spread by formulas | `oorexx_spreadsheet_intentions` (`SpreadsheetReader`) |
| CSV, TSV, DELIMITED | *Data* in a column: a status column, a sheet-error literal | `PiledriverTable` |
| LOG | An *event* | `PiledriverLog` |
| JSON, JSONL | Structured | ooRexx's `json.cls` |

The content decides, not the extension. `GWWIREUI/traffic.log` is a pipe-delimited table, and its fields are hex-encoded text: column 4 decodes to `ACK`, `ACL_ALLOW`, `CLAIM`, `CREATE_QUEUE` and `PUT`.

**2. Is this an error, and is this an error code?** (`PiledriverLog`, `PiledriverWords`)

- *Records.* A record is a head line plus the lines that belong to it:
  - stack traces;
  - indented lines;
  - `KEY: value` lines under a head ending in `:`, e.g. `Error in open:` / `INTCODE: -24`;
  - a Python traceback.

  A heading opens a section, and errors are reported by section. A heading is `== x ==`, `--- x`, `### x`, or a line between two banners.
- *Words.* Each word of a head line is one of these:
  - a plain word;
  - a **code**: `REXX/SQL-24`, `ORA-00942`, `E10`;
  - the **value of a code key**: `rc=-1`, `exit=134`, `INTCODE: -24`, `Error 97.1`;
  - a **value**, which is masked to `#`, `<PATH>` or `<FILE>`.
- *Counts decide what the lists cannot.* There are three rules:
  - A code family or code key whose values are new most of the time is an **identifier**, not a code.
  - A short bare number that comes from a small set at one place in one pattern is a **code slot**. A slot whose values all lie between 100 and 599 is an HTTP status.
  - A named key whose word values come from a small set that contains an OK value is a **status key**. In the IBM 4361 emulator trace, `ST` takes `OK` 101 times and `UNSUPPORTED` twice. That trace has no error word and no level, yet the two failing lines are the only errors found.
- *Verdicts.* `ERROR`, `WARN`, `MENTION`, `OK` or `NONE`, either `STRONG` or `WEAK`, each with its reasons: `LEVEL`, `STACK`, `CODE`, `STATUS`, `HTTP`, `RARE_CODE`, `KEYWORD`.
  - A positive level turns all other evidence into a **mention**. `PASS long unaliased expression returns an error instead of aborting (rc=-16)` mentions an error; it isn't one.
  - A keyword with nothing else behind it is **weak**.
  - Keywords come only from plain words, so `overflow.rex` is a file name, not the word *overflow*.

**3. Have I seen this before?** Each record has these:
- a **template**: the masked head line with its code slots put back;
- a **signature**: the template plus the codes of the whole record;
- a **status**:
  - `NEW`: never seen, in this file or in the catalog;
  - `KNOWN`: seen in the catalog, from another file;
  - `NEW_CODES`: the template is known, but its codes are not;
  - `REPEAT`.

A **rare transition** is a known template that follows a template seen 10 or more times, by a step seen only once. That is SLAM's edge prior, applied to lines. The **catalog** is the memory between files. `compare` lists what is new and what went away.

`PiledriverTable` never searches free text for error words. In the police outcomes file, "Unable to prosecute suspect" is an outcome, not a failure. A table's errors are its sheet-error values and the rows of its status columns. Both the column name and the counts are asked: `lsoa_code` is named like a code and shaped like one (`E01000001`), but 35,672 values in 35,672 rows make it an identifier, and the values decide.

## Gemini's problem (2026-10-30)

Gemini wrote SLAM a problem: a 29-line JVM startup log in unified-logging format (`[0.001s][info][os,thread] ...`) and four tasks (`tests/gemini_to_slam_jvm.md`). SLAM's reader refused the letter. It uses `thread`, `lock`, `safepoint` and other words it never defines; it uses `pattern` in a definition before defining it; and it defines a *line* as what a log is.

**Piledriver as it stood failed the log in four ways, and each is fixed:**
- The deadlock at line 26 was not an error. The level `[error]` sits inside the line's decorations, which Piledriver did not read. Decorations are now read: an uptime or time stamp, a level, then tags, with padding ignored (`[gc        ]` is one tag).
- The ten `Thread attached` lines made seven patterns, one per thread name. Now they make one.
- `java.lang.Class` was read as a file name, because `.class` is a file extension. Extensions now match as written.
- A tag padded with spaces was split into two words.

**New, for the tasks, all general:**
- **Fields.** `key: value` fields, in a group `(id: 1024, name: main)` or at the end of a line (`source: jrt:/java.base`), are judged by Gemini's own rule. A value seen twice or more, in half the lines of its pattern or more, is a *code*. A value seen once is new, so it is a *name*. Anything else is a *repeat*. Seen twice or more is my addition: in a pattern of two lines, a value seen once is "in half the lines" but also new.
- **Name positions.** A plain word at one place in a pattern that is new on every line, in 3 or more lines, is a name (`errors: causing error in <name>`). This is the first step of the template merging listed below.
- **`entityPaths`.** Each thing's path through the log, by its `id` field, its id as a word, or its name. Its state comes from its `state` field or its words. The steps between states are counted as edges.
- **`pairRule`.** Each opening line must be closed before the next opening line or the end of the log, with a proof either way.
- **`groupBy`.** Records grouped by a field's value.

**The answers** (`tests/test_piledriver_gemini_jvm.rex`, 15 checks, every answer worked out by hand from the 29 lines first):
1. Ten threads. Two of them, 1031 and 1032, take the path attached → blocked_on_lock, so "the count of that path is one" is **false** (the count is 2). The edges are START → attached 10, attached → blocked_on_lock 2, blocked_on_lock → deadlock_risk_detected 2.
2. The os,thread lines make two patterns: `Thread attached (id: <id>, name: <name>)` ×10 and `Thread state anomaly detected (id: <id>, state: BLOCKED_ON_LOCK)` ×2. The ids are names (12), the thread names are names (10), and BLOCKED_ON_LOCK is a code (2). The edge count drops to one at **line 24**.
3. The safepoint rule is **true**. Proof: the pairs are lines 10–13, 22–23 and 27–28.
4. jrt:/java.base has Object, String and Class; file:/app/bin/ has CoreEngine and PipelineWorker. Does the final error come from a jrt class or a file class? **I do not know**, as SLAM says, and the answer is neither true nor false. No error line names a class. The order of lines (file classes, then the pool threads, then the deadlock naming two of them) is a prior, not a test. The pool threads' names are made by `java.util.concurrent`, a jrt class, but the log has no class-load line for it, so the log is incomplete.

## Gemini's second problem (2026-10-30)

Gemini sent a second problem: an 11-line server log in log4j/logback form (`[10:00:01.001] INFO  [http-nio-8080-exec-1] c.a.s.RequestHandler - ...`) with four questions (`tests/gemini_to_slam_server.md`). This letter defines 22 words. SLAM had 2 of them already (proves, guess), can add 7, and refuses 13, whose definitions use words it does not have (`doing`, `tool`, `marks`, ...).

**Piledriver as it stood got three things wrong, and each is fixed:**
- **Stack frames.** The frames were each logged as an event with its own stamp and level (`... - <tab>at x.y(Y.java:42)`), so one failure counted as four errors. A stamped line that is a stack frame on the same thread now joins the record before it, and that record carries STACK.
- **Paths.** `uri=/api/v1/user/101` became `<PATH>`. A path now keeps its words, and only a number segment is masked: `/api/v1/user/#`, `#.html`, `#:#:#:#`.
- **Threads.** The thread of a line (`[http-nio-8080-exec-2]`) was not kept. It is now `context`.

`record~body` is the text after a logger's ` - `, and `fieldSeries` gives a field's values in order.

**The answers** (`tests/test_piledriver_gemini_server.rex`, 15 checks, every answer worked out by hand first):
1. Two URIs, `/api/v1/user/101` and `/api/v1/user/102`, make **one** pattern, `/api/v1/user/#`, across three request patterns (START, END, FAIL). Gemini's rule says the id is a name inside the START pattern. Over all four URI lines, though, each id appears in half of them, so the rule calls it a code: four lines are too few for the rule.
2. Gemini's premise is wrong. `active` counts the connections in use across the whole pool, not for one thread. The series is 1, 2, 1, 0 (lines 3, 4, 6, 11). A Borrow adds one and a Return takes one away (**true**), and active + idle = 10 (**true**). The 1 is at line 6, when exec-1 returns its connection, so nothing is missed. exec-2 borrows once and returns once, after the error, so no connection leaks.
3. The premise is wrong again. Lines 9 and 10 start with a time stamp, and the tab comes after the logger's ` - `. They are stack frames on the same thread as line 8, so they **join the error record**: 11 lines, 9 records, 2 errors.
4. The error class is `java.lang.OutOfMemoryError`. The top frame is `com.app.service.DataBuffer.allocate(DataBuffer.java:42)`, so "thrown in DataBuffer" is **true**. "DataBuffer is the cause of the memory use" is **I do not know**: the error is thrown by the allocation that fails, not by the code that used the memory, and the log has no heap data. The trace also has only 2 frames, with no thread entry frame at the bottom.

## What it found in the estate

| File | Lines | Found |
|---|---|---|
| `ibm_4361…/safety17_compile.log` | 1,033 | 9 patterns. The ooRexx banner appears 129 times. No error |
| `oorexx_rexxsql_backend_v0.1/evidence/mark_tester_unpatched.log` | 197 | 91 records, 16 errors. `Error in open:` at line 191 is `NEW_CODES`: the template was seen before, but `INTCODE=-62` was not |
| The same tester, unpatched → patched | | One pattern went away: `rm: cannot remove '<FILE>': No such file or directory` (2×, ERROR). Nothing new arrived |
| `…/defects_unpatched.log` → `defects_patched.log` | 12 | `*** buffer overflow detected ***: terminated`, `exit=134`, `rc= -1` → `exit=0`, `rc= -16` |
| `ibm_4361…/mvt_safety8_permanent_bal_progress.log` | 209 | 24 patterns at first, 9 once register values were treated as values. 2 errors (`ST=UNSUPPORTED`), found by counts |
| SLAM's own `run_tests.sh` output, on a shallow clone | 391 | 4 errors. The 2 strong ones are the real failure (the provenance check, `exit=1`). The 2 weak ones are SLAM's predictions that an edge "will fail" |

## Files

| File | Role |
|---|---|
| `src/PiledriverWords.cls` | The closed lists (levels, error words, code keys, OK values, sheet errors, months) and token shapes (code shape, mask, hex text, time stamps) |
| `src/PiledriverSource.cls` | What kind of file, with its evidence |
| `src/PiledriverLog.cls` | Records, templates, codes, verdicts, seen-before, transitions, the catalog |
| `src/PiledriverTable.cls` | Header, column roles (STATUS, ID, CONSTANT, CATEGORY, VALUE), status error rows, sheet-error cells by A1 address |
| `bin/piledriver.rex` | `sniff`, `read`, `errors`, `learn`, `compare` |
| `tests/test_piledriver.rex` | 101 checks: 88 on the files above and the standard formats, and 13 from the independent review |
| `tests/claude_to_slam_piledriver.md`, `tests/slam_to_claude_piledriver.md` | Claude's question to SLAM, and SLAM's reply (both read with no unknown word) |
| `tests/test_piledriver_gemini_jvm.rex`, `tests/fixtures/piledriver/jvm_startup.log` | Gemini's problem: 15 checks |
| `tests/test_piledriver_gemini_server.rex`, `tests/fixtures/piledriver/server_crash.log`, `tests/gemini_to_slam_server.md`, `tests/slam_to_gemini_server.md` | Gemini's second problem: 15 checks, and the letters |
| `tests/gemini_to_slam_jvm.md`, `tests/slam_to_gemini_jvm.md` | Gemini's letter (SLAM's reader refuses it, and its reply says why) and SLAM's reply (read with no unknown word) |

```
export REXX_PATH=packages/oorexx_slam_v0.1/src
rexx packages/oorexx_slam_v0.1/bin/piledriver.rex sniff FILE
rexx packages/oorexx_slam_v0.1/bin/piledriver.rex read FILE
rexx packages/oorexx_slam_v0.1/bin/piledriver.rex learn CATALOG OLD_RUN.log
rexx packages/oorexx_slam_v0.1/bin/piledriver.rex compare CATALOG NEW_RUN.log
rexx packages/oorexx_slam_v0.1/tests/test_piledriver.rex "WORK|REPO"
```

## The independent review

A separate agent reviewed the code: Claude (Opus 5.5), which had not seen it being written, working from the code and these rules alone. It found 8 defects and confirmed each one by running it. All 88 checks had passed, so each defect was a gap in the tests, not a test failure. Each one is now fixed, with a check that failed before the fix (section 13):

- A word after a code key was taken as an error code. `STATUS: running` came out as a STRONG error. Now only a number, a code or a SQLSTATE is a code value, and word values are left to the counts: `status=done` ×11 with `failed_hard` ×1 finds the one error.
- `WARNING:` and `ERROR:` lines joined a block opened by `Compiling module:`.
- A UTF-8 byte order mark was not removed, in a log or in a table header.
- A CSV with a leading blank line took the blank line as its header.
- In a status column, level words were tested before OK values. With `OK`/`TIMEOUT`, the TIMEOUT rows were not errors; with `OK`/`TIMEOUT`/`DENIED`, they were. Now OK values come first.
- `[0] starting` lines were sniffed as JSON.
- A heading with ERROR or FAILED in it (`-- 3 tests FAILED`) was silenced as a heading. Now it is a record.
- `SHA256`, `WIN32`, `X86` and `ISO8601` were taken as codes. They are now on a closed list of names.

It also found four things by reading, and these are fixed too:
- ties in a count were decided by `.Directory` order; they now go by sorted order;
- a catalog line with CR at the end is now read correctly;
- saving one log's catalog twice no longer counts it twice;
- the mask comment did not match the code.

Two more fixes came from the review's cases. A key name such as `error=false` is no longer read as the word "error". A key named as a status, with no OK word among its values, takes its most used value as normal.

## What it does not do yet

- **Template merging.** Only a word that is new on every line is merged, as a name. Drain also merges words that repeat, by similarity, and that is the next step.
- **Workbooks.** Piledriver does not open XLSX or ODS itself; `SpreadsheetReader` does. In `SpreadsheetOpenFormats.cls`, the XLSX path marks error cells `valueType = "ERROR"`, but the ODS path has no error branch. LibreOffice is believed to save error results as text (`#DIV/0!`, `Err:502`), but this has not been checked against an ODS fixture. `PiledriverTable` catches those values by their literal form. Joining the two (workbook cells into `PiledriverTable`'s column roles) is a change to that package, which is not this component's to make.
- **Speed.** `csvStream.cls` reads the 35,672-row LSOA file in about 23 to 26 seconds. Logs are fast: 1,033 lines take 1.3 seconds.
- **Into SLAM's store.** Templates are kept in ooRexx collections and the catalog file. Writing them to `SlamStore` as nodes, with transitions as edges, would let SLAM score paths through a log the way it scores paths through code.
