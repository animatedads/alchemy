# ooRexx Source / Code / Class Editor v0.1-dev9

A native ooRexx implementation of the NewShell code/class editing model. This is **not** the emergency line editor. It is the normal development/source editing API that AI assistants, NewShell tools, class builders and CLI UI front-ends can consume.

The implementation language is ooRexx. The editing model is deliberately language-neutral.

## First-tier languages

- ooRexx: package/class/method/routine/attribute/`::requires` discovery; `RexxClassEditor`; `::requires` additions fail closed until the target resolves through explicit search paths.
- C and C++: `.c`, `.h`, `.cc`, `.cpp`, `.cxx`, `.hh`, `.hpp`, `.hxx`, `.ipp`, `.tpp`, `.inl`, `.inc`; comment/string-aware projection; class/struct/enum/namespace/function/macro/include symbols; bounded brace scopes; `CppClassEditor` member/include editing.
- JSON/JSONC: first-class profile, key projection, JSON validation through the ooRexx-distributed `json.cls`.
- Python: class/function block discovery.
- text/config: deterministic line/range editing.

C/C++ associated files are intentionally first-tier rather than pretending `.cpp`, `.hpp`, `.inl`, `.tpp`, etc. are generic C-like text.

## Core API

```rexx
doc = .SourceDocument~new('newshell_host.cpp')
do s over doc~symbols
    say s~asString
end

doc~replaceLine(42, '    return EXIT_FAILURE;')
doc~save
```

`SourceDocument~save` rereads the source and refuses to overwrite it when the on-disk generation differs from what was loaded. Dev6 publishes both the optional `.newshell-bak` sibling and the live candidate through `oorexx.atomic-file/0.1` with `FULL` durability requested. `lastBackupResult` and `lastPublicationResult` expose the Atomic File evidence. Atomic File dev1 cannot provide race-free expected-generation CAS or an integrated backup transaction, so the SourceDocument generation fence remains an application-level precondition and the backup+target pair is not claimed as one atomic transaction.

## Finding and grep

`SourceFinder` is a reusable object over `SourceDocument`. It returns `SourceMatch` objects with original line/column, source text, search kind and enclosing symbol evidence.

Literal find remains literal:

```rexx
matches = doc~find('needle','code','insensitive')
```

Regular-expression grep delegates matching to ooRexx's shipped `rxregexp.cls` / `.RegularExpression` implementation:

```rexx
matches = doc~grep('SourceF[a-z]+','code','sensitive')
```

The editor does not emulate Python/PCRE regex syntax. Patterns use the selected ooRexx runtime's `RegularExpression` semantics. For example character classes and quantifiers are native ooRexx behavior; callers should not assume that `.` has PCRE wildcard meaning.

Both operations accept `text` or `code`. `code` mode first uses the language-aware source projection, so comment-only occurrences are ignored while returned line/column coordinates still refer to the original physical source.

CLI forms:

```text
code-editor find FILE WORDS... [--mode text|code] [--case sensitive|insensitive]
code-editor grep FILE REGEX... [--mode text|code] [--case sensitive|insensitive]
```

Dev7 adds `SourceEditorCliSearchArgs`: the flattened command tail is interpreted as a complete middle-field search expression plus explicit `--mode` / `--case` switches. The older single-token positional form remains compatible.

## Class editing

```rexx
paths = .array~of('/project/classes', '/project/packages')
e = .RexxClassEditor~new('Worker.cls', paths)
e~addRequires('BaseWorker.cls')  -- fails closed if not resolvable
e~addMethod('Worker', 'status', 'return "ready"')
e~document~save
```

C++:

```rexx
e = .CppClassEditor~new('worker.hpp')
e~addInclude('<cstdint>')
e~addMember('Worker', 'std::uint64_t generation() const;')
e~document~save
```

## Dogfood rule

NewShell development should use this API / its CLI for source inspection and mutation once the needed operation exists. Falling back to unrelated host editing tools is a bootstrap escape hatch; a missing operation is a source-editor defect/backlog item.

Dev3 itself was changed through `SourceDocument`: `SourceFinder`, the CLI grep branch, tests and package documentation were all published through generation-checked editor saves.

## Source-tree finding

`SourceTreeFinder` provides recursive source discovery without shelling to `find`. It delegates traversal to RexxUtil `SysFileTree` and returns `SourceFileMatch` objects carrying path and detected language.

```rexx
finder = .SourceTreeFinder~new('/project')
files = finder~files('*.cls','oorexx')
matches = finder~grep('Process[A-Za-z]+','*.cls','code','sensitive','oorexx')
```

CLI forms:

```text
code-editor find-file ROOT FILESPEC [LANGUAGE]
code-editor grep-tree ROOT REGEX [FILESPEC [text|code [sensitive|insensitive [LANGUAGE]]]]
```

Tree grep does not implement another regex engine. Each candidate file is opened as a `SourceDocument`, projected through the existing language-aware code/text model, and matched by ooRexx `.RegularExpression`. This keeps filesystem traversal, source semantics and regex authority separate.

## Dependencies

- ooRexx 5.3.0 r13196 qualification target.
- RexxUtil (shipped with ooRexx) for filesystem helpers.
- `json.cls` from the selected ooRexx distribution.
- `rxregexp.cls` plus `librxregexp` from the selected ooRexx distribution for native grep regular expressions.

The runtime/package path must make the declared `::requires` dependencies resolvable.

## Current limitations

C/C++ symbol discovery is a deterministic lexical/brace scanner, not a substitute for a compiler AST. It deliberately reports only ranges it can bound. A future compiler-backed provider can strengthen symbol/reference evidence while preserving the same editor API. JSON structural mutation by JSON Pointer, semantic C++ references, and richer guarded change/reference navigation remain next gates.

## Dev5 completion and semantic-source boundary

Dev5 adds `SourceCompletionCandidate` and `SourceCompletionProvider`. Completion is an ooRexx object API; terminal output is only one projection. `complete` returns symbols from one `SourceDocument`, while `complete-tree` returns source-file candidates discovered through `SourceTreeFinder` / RexxUtil `SysFileTree`.

This aligns with NewShell's public completion request/reply seam: CLI/UI, MCP and deterministic LLM clients can consume one structured candidate contract rather than scrape displayed text.

### Semantic Source Store / Development Desk

The editor does **not** duplicate Semantic Source Store authority. Development Desk owns semantic object creation (`CREATE_PACKAGE`, `CREATE_CLASS`, `ADD_ATTRIBUTE`, `ADD_METHOD`) and materialisation. `SourceDocument` owns conventional materialised-file inspection/editing. A future adapter may present semantic objects through editor views, but creation/revision authority remains with the semantic store.

```text
code-editor complete FILE [PREFIX [KIND]]
code-editor complete-tree ROOT [PREFIX [FILESPEC [LANGUAGE]]]
```


## Dev6 Atomic File publication

Dev6 removes Source Editor's direct live-file replacement path. Save now:

1. rereads the current source and rejects stale loaded generations;
2. publishes the recovery sibling through `.AtomicFile~replace` when backups are enabled;
3. publishes the candidate through `.AtomicFile~replace`;
4. requests `FULL` durability, target no-follow, existing mode preservation and `backupPolicy=NONE`;
5. exposes the returned `AtomicFileResult` objects.

If Atomic File reports `published=.true` but `ok=.false` (for example a post-rename parent-directory sync failure), SourceDocument updates its remembered generation to the published candidate before surfacing the durability failure. It therefore never pretends the old source is still current after a partially satisfied durability promise.


## Dev7 multi-word CLI search

Dev7 removes the old assumption that host-shell quoting can be reconstructed after ooRexx receives the flattened script command tail. `SourceEditorCliSearchArgs` instead treats all non-option middle tokens as the search expression and gives mode/case explicit syntax:

```text
code-editor find FILE words with spaces --mode code --case insensitive
code-editor grep FILE regular expression here --mode text --case sensitive
```

The historical single-token positional form remains supported:

```text
code-editor grep FILE token code insensitive
```

For multi-word expressions, explicit switches avoid ambiguity when the expression itself ends in words such as `code` or `sensitive`. The parser is native ooRexx and has regression coverage for both the multi-word and compatibility forms.


## Dev8 reference navigation

Dev8 adds a first bounded reference-navigation slice without pretending to provide compiler-grade semantic analysis.

`SourceDocument~references(name [, caseMode])` and `SourceTreeFinder~references(name [, filespec [, caseMode [, language]]])` reuse the language-aware `code` projection and literal finder. Each returned `SourceMatch` now carries `role`:

- `declaration` when the occurrence lands on the start line of a scanner-known symbol with the same name;
- `reference` for other code occurrences;
- `match` remains the neutral default for ordinary find/grep results.

CLI projections:

```text
code-editor references FILE NAME [sensitive|insensitive]
code-editor references-tree ROOT NAME [FILESPEC [LANGUAGE [sensitive|insensitive]]]
```

This is deliberately lexical/source-aware. It preserves path, physical line/column, original text and enclosing-symbol evidence, but it does not claim overload resolution, dynamic dispatch resolution, macro expansion, compiler AST identity or cross-language semantic binding. Those stronger forms can be introduced later behind the same navigation/result boundary.

## Dev9: it works, and it can read, line edit / amend, lint and check

Architecture: Tom Dyer ("the editor features need line edit / amend / read, lint and check").
Coding of dev9: Claude (Opus 5.5). Earlier versions: ChatGPT (dev1-dev8). Lint rules P1-P4:
`PitfallChecker.cls`, written by Claude (Opus 5.5) for oorexx_slam_bostoncrab v0.24, copied
here unchanged.

**Why dev8 did not run.** Two faults stopped it loading at all:
- the last lines of `SourceEditor.cls` held `::requires "AtomicFile.cls"` and
  `::requires "rxregexp.cls"` on one line joined by a literal `\n` (Error 25.904);
- `SourceEditorCliSearchArgs~init` assigned `self~expression=...` to GET-only attributes.
With both fixed, the whole dev8 suite passes with oorexx_atomic_file v0.1-dev1.

**New in dev9.**

| What | API | CLI |
|---|---|---|
| read | `doc~lines`, `doc~line(n)` | `show FILE [FIRST [LAST]]` |
| insert | `insertBefore(n, text)`, `insertAfter(n, text)` | `insert-before FILE LINE "TEXT"`, `insert-after ...` |
| amend | `old = doc~amend(first, last, text)` returns the replaced lines; `last = first-1` inserts | `amend FILE FIRST LAST "TEXT"` or `--from TEXTFILE` |
| lint | `doc~lint` returns `SourceLintFinding` (rule, line, column, text, message) | `lint FILE` (exit 1 on findings) |
| check | `doc~check` returns `SourceCheckResult` (ok, code, line, message, dependencies) | `check FILE` (exit 1 on a syntax error) |
| guarded save | `doc~saveChecked` | every CLI edit uses it |

- **lint** (ooRexx): P1 `"s"(x)` is a call; P2 `'s'x` is a hex literal; P3 two names that
  differ only in case; P4 a USE ARG name reused as a loop variable; P7 `call x~y` is a syntax
  error; P9 a variable named RESULT, RC or SIGL (ooRexx sets them itself).
- **check** compiles the source with `.Routine~new`, with its `::requires` lines blanked so the
  line numbers stay true. A `::requires` that is not beside the file or on REXX_PATH, or a
  class the source names but does not define (98.909, 43.901), is reported as a
  **dependency**, not a syntax error.
- **saveChecked** refuses an edit that makes an ooRexx file stop compiling, when it compiled
  at load. A file that was already broken can still be edited: that is how it gets fixed.
  `validate` for ooRexx is now `check~ok` (it used to return .true for anything but JSON).
- **code mode for ooRexx**: `--` comments and nested `/* */` comments are ignored; a doubled
  quote stays inside its string; there are no backslash escapes. (Dev8 used the C rules for
  every language.) The C rule for a backslash escape compared one character with `'\\'`,
  so it never matched; it now compares with `'\'`.
- the code projection no longer uses a variable named RESULT.
- CLI exit codes: 0 done; 1 lint findings, a syntax error, or invalid; 2 usage or error.

**rxregexp facts for `grep` (probed on ooRexx 5.3.0, not taken from memory).**
`?` matches any one character; `.` is a literal dot. Alternation `|`, groups, `*`, `+`,
`{n,m}`, `[a-z]`, `[[:digit:]]` and `[[:alpha:]]` work. There is no `\d` and no
lookahead `(?=...)`. `grep Atomic?ile` matches `AtomicFile`.

**Run the tests**
```
bash tests/run_tests.sh
```
It copies the package and oorexx_atomic_file v0.1-dev1 to a temporary directory, builds the
Atomic File native library there, runs both suites, then checks and lints the editor's own
sources with the editor.
