# Language guidance

Language behavior is represented by structured `language-module` objects plus language-rule pages. This file is a compact human rendering.

## Language-module contract

A module declares:
- file extensions / source kind;
- examiner capability;
- exact-symbol language semantics;
- optional grouped-rule capability;
- optional compiler/validator capability;
- default sphere.

Use:

    gopher language resolve SomeFile.java
    gopher --profile java language describe java

The module deliberately does **not** imply that editing is available. Examination, validation and mutation are separate capabilities.

## ooRexx

Use the exact available ooRexx runtime for translation evidence. Source edits are bounded structural mutations; unrelated source bytes are preserved. Deterministic rule breaches are returned as one grouped set.

## Python

Python examination uses the AST. Existing method editing uses AST source spans and whole-module parse validation. Deterministic/advisory rule breaches are returned together. Interpreter resolution is `LLM_GOPHER_PYTHON`, then `python3`, then `python`.

## C/C++

The current C/C++ module publishes source examination and exact class-symbol lookup. It does not yet claim a compiler or structural editor.

## Java

Java is first-class in v0.17:
- `.java` source kind;
- package/import/type/method examination;
- exact class/interface/enum/record lookup, with type declaration preferred over a same-named constructor;
- `javac` compile validation with explicit release/classpath/sourcepath evidence;
- grouped deterministic/advisory language rules;
- a `java` sphere with project-grounded Swing/JMS lessons.

Java editing is **not** advertised yet. A Java structural editor should only be added when it can preserve unrelated source and validate the full candidate safely.

Use `gopher rules check` and `gopher rules show` for machine-readable rule objects.
