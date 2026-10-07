# ooRexx Source / Code / Class Editor v0.1-dev3

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

`SourceDocument~save` rereads the source and refuses to overwrite it when the on-disk generation differs from what was loaded. It retains a complete `.newshell-bak` sibling before publication. It does **not** claim crash-durable atomic publication; that belongs to `oorexx_atomic_file` when that library is wired in.

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
code-editor find FILE NEEDLE [text|code [sensitive|insensitive]]
code-editor grep FILE REGEX [text|code [sensitive|insensitive]]
```

The current development CLI receives a flattened command tail from the ooRexx launcher. Multi-word patterns therefore remain an explicit CLI parser backlog item; the object API itself accepts arbitrary strings correctly.

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

## Dependencies

- ooRexx 5.3.0 r13196 qualification target.
- RexxUtil (shipped with ooRexx) for filesystem helpers.
- `json.cls` from the selected ooRexx distribution.
- `rxregexp.cls` plus `librxregexp` from the selected ooRexx distribution for native grep regular expressions.

The runtime/package path must make the declared `::requires` dependencies resolvable.

## Current limitations

C/C++ symbol discovery is a deterministic lexical/brace scanner, not a substitute for a compiler AST. It deliberately reports only ranges it can bound. A future compiler-backed provider can strengthen symbol/reference evidence while preserving the same editor API. JSON structural mutation by JSON Pointer, semantic C++ references, atomic publication, and robust multi-word CLI argument transport remain next gates.
