# Sphere: oorexx-llm-pitfalls v0.1

A narrow, evidence-grounded sphere: specific ooRexx traps that produced
a real incident during this project's own development, packaged as
Gopher language-rule and article packs.

## Contents

- `OOREXX.STRUCTURE.PROLOG_AFTER_DIRECTIVE` -- top-level code placed
  after the first `::` directive is silently unreachable, not a syntax
  error.
- `OOREXX.OPERATOR.NONSHORTCIRCUIT_BOOLEAN` -- `&`/`|` always evaluate
  both operands; a guard-then-risky pattern needs nested `if`, not a
  compound boolean.
- `OOREXX.SYNTAX.TRAILING_COMMA_CONTINUATION` -- a trailing comma
  continues the line, including inside a multi-line argument list.
- `OOREXX.NIL.UNASSIGNED_ARG_CHECK` -- an optional `USE ARG` parameter
  with no default needs a `symbol()` guard before a `.nil` comparison
  means what it looks like it means.
- `ops.oorexx.expose-scope-per-defining-class` (article, not a rule --
  see the entry for why) -- `expose` is scoped per defining class in
  the hierarchy, not per object; a same-named subclass expose does not
  alias a superclass's.

## Sphere composition

`inherits_services_from: ["oorexx"]` -- this sphere is documentation
and diagnostics only. It deliberately does not define its own
source-examine/source-edit services; it reuses the `oorexx` sphere's
existing ones rather than duplicating them, per the non-transitive
inheritance invariant already established for sphere composition
(`ops.sphere.service-inheritance`): only this sphere's own
`inherits_services_from` entry expands its visibility, and its own
access policy is what gets re-evaluated for anything inherited.

## What is deliberately not here

General ooRexx style preference, anything not traceable to a real
incident, and anything whose only detectable signal is "this looks
suspicious" rather than a defensible trigger condition. Two candidate
entries were downgraded from language-rule to article specifically
because their trigger would have been too heuristic to state honestly
as a reliable mechanical check.
