# LLM Gopher v0.20-dev1

Executable development increment of the Gopher-like operational navigation substrate for LLMs.

## What v0.10-dev1 changes

v0.10-dev1 adds navigable operation-result pages and resumable result/rule cycles on top of the v0.9 Gopher+ form substrate. ASK submission remains backward-compatible structured JSON, but successful submission also registers that exact response under a bounded runtime selector such as `/result/<digest>` and returns the selector in `navigation.result_selector`.

A result page summarizes tool status, operation status, selected result/evidence fields, actual service route/fallback depth, and safe next selectors. If the response contains grouped language-rule breaches, **all breaches are rendered together**, each with its `> CORRECT:` guidance and a result-relative rule-detail selector. Following `/result/<id>/rule/<rule-id>` opens the existing LanguageRulePage semantics and publishes `< RETURN TO RESULT` back to the exact originating result.

Executable capability forms remain sphere-qualified (`/form/<sphere>/<capability>`) and authority is re-evaluated at submission. Result pages do not create a new execution path: `> Run again` returns to the authorised form, while `< RETURN` returns to the originating capability/page. Runtime result state is server-local and contains the already-produced response; it does not grant bearer authority.

The v0.9 schema-generated `+ASK` form behavior remains intact and continues to use the same capability schemas, validation, Finder and ServiceProxy route as CLI execution.


## What v0.8-dev2 changes

v0.8-dev2 is a portability/qualification correction with no intended semantic change to the Gopher engine. The launcher and test harness now resolve the Python runtime as a capability: explicit `LLM_GOPHER_PYTHON`, then `python3`, then `python`. A python3-only host is covered by regression testing, and absence of all candidates returns a structured `UNAVAILABLE` diagnostic rather than relying on a shell `command not found`.


## What v0.7 changes

v0.7 makes language-specific rules first-class grouped diagnostics. A rule pass reports every determinable breach for the current source version at once; each breach includes the precise cause, observed location/evidence, a `> correct` correction, fixability (`AUTOMATIC`, `SUGGESTED`, or `MANUAL`), a LanguageRulePage selector, and a durable cycle selector used to return to the originating work.

Commands:

    ./gopher --profile oorexx rules check Foo.cls --language oorexx
    ./gopher --profile oorexx rules show OOREXX.REQUIRES.DUPLICATE --language oorexx --return-to cycle://...

The machine-readable capability is `source.language.rules.evaluate`. Missing arguments are `INVALID_ARGUMENT`, not `NOT_FOUND`. Rule documents are semantic pack objects and therefore participate in deterministic merge/conflict handling.

The initial deterministic rules are deliberately conservative: ooRexx duplicate class, duplicate method, and duplicate `::requires`; Python parser failure, duplicate class method, wildcard import, and bare `except`. Structural blockers prevent an editor commit. Advisory breaches do not block a syntactically valid edit, but are returned in the successful edit evidence.

The rule cycle is intentionally grouped: one source version -> one complete known breach set -> optional detail-page diversion -> return to the same cycle -> selected bounded corrections -> re-evaluate all rules.

## What v0.6 changes

v0.6 turns safe source editing into a first-class, gated service. It preserves v0.5 profiles, task-oriented source examination, machine-readable capability schemas, strict JSON argument validation, archive-native nested ZIP examination, Finder/service proxies, page handlers, evidence-backed checklist state, access control, fallback routing, and fail-closed semantic pack merge.

The central source-edit invariant is:

> An edit changes only the declared target region unless wider transformation scope is explicitly requested.

The engine therefore does not regenerate an existing source file from a partial in-memory class model.

### Bounded ooRexx method editing

Capability:

    source.oorexx.method.edit

Task-oriented form:

    ./gopher --profile oorexx edit method Sample hello \
      --in Sample.cls \
      --replacement /tmp/hello.rex

The replacement file contains one complete `::method` directive and body. The editor resolves the named class and method, rejects missing/duplicate/ambiguous targets, computes the exact method source span, splices only that span, runs `rexxc` against a temporary complete candidate, and atomically replaces the original only after successful translation.

### Bounded Python method editing

Capability:

    source.python.method.edit

Task-oriented form:

    ./gopher --profile oorexx edit method Sample hello \
      --in sample.py \
      --replacement /tmp/hello.pyfrag

The Python editor uses the AST to resolve the exact class/method span. A replacement is one complete method definition. The complete candidate module is parsed before commit. Unrelated imports, comments, sibling methods, other classes and formatting outside the target span remain untouched.

### Edit evidence

Successful edits return structured evidence including:

- operation (`ADD` or `REPLACE`);
- exact class/method target;
- changed source range;
- SHA-256 before and after;
- bounded unified diff;
- validator identity/result;
- commit status;
- Finder/service route.

`expected_sha256` provides stale-source fencing. If the source has changed since examination, the edit returns `STALE_SOURCE` and does not write.

Validation failures return `VALIDATION_FAILED` with `committed=false`. A malformed replacement never reaches the target file.

### Operations Guide rule

`ops.source.edit.safe` records the source-edit rules and classifies the recurring LLM failure mode:

    SOURCE_EDIT.REGENERATE_INSTEAD_OF_EDIT

The v0.6 regression suite deliberately creates existing ooRexx and Python sources containing unrelated sentinels and proves those bytes survive a method replacement. This directly guards against the lossy "partial model -> rewrite the whole class/file" pattern.

## Existing LLM interface

Capability schemas remain discoverable:

    ./gopher --profile oorexx describe source.oorexx.method.edit --sphere oorexx

Common source examination remains task-oriented:

    ./gopher --profile oorexx examine source Maths.cls \
      --in /path/oorexxapis.zip \
      --symbol MathInteger

Nested ZIP source remains queryable without extraction.

## Core invariants

- Tool status and operation status are separate.
- Missing/malformed arguments return `INVALID_ARGUMENT`, not `NOT_FOUND`.
- `NOT_FOUND` is a successful observation and never triggers fallback.
- Fallback occurs only for eligible service-level failures.
- Models receive authorised service proxies, not implementation objects.
- Mutating operations validate complete candidate state before atomic commit.
- Stale-source edits can be fenced by expected SHA-256.
- Archive members and nested ZIPs can be searched/read without filesystem extraction.
- Reads/searches are bounded.
- Checklist ticks require evidence.
- Pack merge uses stable `(kind,id)` identity and rejects conflicting definitions; there is no last-writer-wins path.
- Access control filters published capabilities and is checked again at invocation.

## Version identity

Package: `LLM Gopher v0.10-dev1`

Wire/result schema: `llm-gopher/0.10`

## Tests

    ./tests/run.sh
    ./tests/run_v03.sh
    ./tests/run_v04.sh /path/oorexxapis.zip
    ./tests/run_v05.sh /path/oorexxapis.zip
    ./tests/run_v06.sh
    ./tests/run_v07.sh
    ./tests/run_v08.sh
    ./tests/run_v08_portability.sh
    ./tests/run_v09.sh
    ./tests/run_v10.sh

Qualification used the supplied ooRexx 5.3.0 r13196 Internal Test Version and the supplied `oorexxapis(20260902-003405).zip`.

## v0.8-dev1: selector and protocol surface

The same semantic engine can now render a real Gopher menu surface with `selector` and can serve it over TCP with `serve`.  Selectors are access-controlled views over existing spheres/articles/capabilities/rules; they do not bypass Finder/ServiceProxy authority.  `--plus` emits machine-oriented Gopher+ attributes.

Common task commands now also accept named forms so humans and LLMs do not have to remember positional order, for example `examine source --source Maths.cls --in library.zip`, `edit method --class Foo --method bar ...`, and `rules check --in Foo.cls`. Positional forms remain compatible.

## v0.11 package staging

Use `gopher package stage` to build a clean candidate tree and `gopher package check` to return all packaging breaches, tests, and referenced environment variables together before sealing.

## v0.13 setup / launch

`./gopher setup` is handled by the shell bootstrap before normal engine dispatch. It checks Python and unpack tools, discovers an ooRexx runtime or supplied `.deb`, creates a private environment, writes `state/setup.json`, exports the resolved runtime, and launches the requested Gopher command. Use `--no-launch` to prepare only, `--oorexx-deb PATH` to bind an exact package, and `--env PATH` to choose the private environment. No software download is attempted.

## v0.14 self-documenting help

`gopher setup -h` is shell-native and side-effect free. Root `gopher -h` always begins with setup/bootstrap guidance; if Python and ooRexx actually execute successfully, it appends `YOU SHOULD BE USING THIS` plus live operational pages and published service scope derived from the loaded sphere/articles/capability schemas.

Use `gopher --profile oorexx help oorexx` for the same live scope as structured JSON.

## v0.15 sphere-driven engine improvements

A sphere may declare `"inherits_services_from": ["oorexx"]` to deliberately reuse services scoped to another sphere while keeping the destination sphere's access policy authoritative.

Typed corpus lookup is available as:

    gopher --profile maths lookup topic=precision --sphere maths
    gopher --profile s370mvs lookup opcode=5D --sphere s370mvs

Exact field matches are returned before any bounded text fallback.

## v0.16 sphere retrieval

Use `gopher sphere resolve/load/list`. Delivered spheres are discovered under `current/sphere/*.zip` in an ooRexx API roll-up. Local override datasets take precedence and every activation records source/version/SHA-256 provenance.

## v0.17 language modules

Language support is now described by `language-module` objects. Use:

    gopher --profile java language describe java
    gopher --profile java language resolve SomeClass.java
    gopher --profile java examine source SomeClass.java --in <path-or-zip> --symbol SomeClass
    gopher --profile java exec source.java.compile path=SomeClass.java release=17 sphere=java
    gopher --profile java rules check SomeClass.java --language java --sphere java

The Java sphere includes project-grounded Swing/JMS lessons from the delivered ooRexx API roll-up.

## v0.18 workspace-gpt

Ephemeral-workspace checks are first-class:

    gopher --profile workspace-gpt workspace inspect
    gopher --profile workspace-gpt workspace materialize-check --path /mnt/data/input.zip --expected-bytes 31457280
    gopher --profile workspace-gpt workspace preflight-zip /mnt/data/input.zip --workspace-limit-bytes 62914560
    gopher --profile workspace-gpt workspace handover-frame --task "..." --next-action "..." --artifact /mnt/data/candidate.zip
    gopher --profile workspace-gpt workspace recoverability

ZIP preflight uses central-directory metadata before extraction. Declared session quotas override optimistic host `df` headroom when smaller. `HANDOVER_ADVISED` means do not start the planned file-heavy operation in this workspace.

## v0.19 Sphere Editor

Use the built-in authoring guide and editor:

    gopher --profile sphere-authoring context sphere-authoring --full
    gopher sphere edit create <sphere> --path <workdir> --title "..."
    gopher sphere edit template article --sphere <sphere> --id <id> --title "..." --out article.json
    gopher sphere edit put article --sphere <sphere> --path <workdir> --from article.json
    gopher sphere edit evidence article <id> --sphere <sphere> --path <workdir> --artifact ... --sha256 ... --member ...
    gopher sphere edit validate <sphere> --path <workdir>
    gopher sphere edit lint <sphere> --path <workdir>
    gopher sphere edit package <sphere> --path <workdir> --out <sphere.zip>

The editor owns canonical structure. The author owns semantics.

## v0.20 sphere sections and roll-up

Articles may carry `section` and `topics`. `context`/`menu` return both the flat article list and grouped sections.

The built-in `sphere-authoring` profile is now v0.3 and includes Authoring Craft plus Sphere Internals. The built-in `gemma-oorexx` profile is the normalized v0.2 stabilization memory.

See `SPHERE_SET.md` for the companion external sphere roll-up.

## v0.21 reference reader

Gopher can now fetch/read/search/navigate PDF or HTML references from disk or HTTP(S):

    gopher reference find <source> <string>
    gopher reference locate <pdf> --reference-page N --approx-page M
    gopher reference read <source> --page P
    gopher reference move <source> --page P 1

Use `gopher reference -h` for the complete working cycle. The built-in `manual-navigation` sphere explains when to use find versus locate, how printed/manual pages differ from physical PDF pages, and how to return to the originating task after bounded evidence reading.
