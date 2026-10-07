# Ruby ↔ ooRexx dispatch design

## Missing method symmetry

Ruby unresolved send:

`Ruby normal lookup → method_missing → Rexx projection endpoint → ooRexx normal lookup → ooRexx UNKNOWN`

ooRexx unresolved send:

`ooRexx normal lookup → composed UNKNOWN → Ruby actual send → Ruby normal lookup → Ruby method_missing`

Neither side may treat introspection (`respond_to?` or a method-table query) as permission to suppress actual dispatch.

## Exception boundary

Three outcomes are required from native Ruby dispatch:

1. `value` — Ruby returned normally.
2. `missing` — Ruby exhausted its own normal lookup and `method_missing` protocol with a genuine unresolved-method result attributable to this send.
3. `raised` — Ruby code raised. This propagates as a structured foreign condition and MUST NOT invoke the preserved ooRexx UNKNOWN fallback.

## Identity and lifetime

Native implementation will keep a bidirectional registry:
`Ruby VALUE/object_id ↔ foreign handle ↔ retained Rexx global reference`.

Returning a projection to its originating runtime unwraps it to the resident original. Handles are retained while reachable and explicitly/reliably released; serialization is not an identity mechanism.

## Live mutation/interposition

The bridge must dispatch each non-overridden Ruby send against the current Ruby object/class/singleton-class method graph. It must not cache the Method that happened to exist when projected. Rexx object-local overlays shadow the Ruby target through the Alchemy coordinator; removing the overlay reveals the current Ruby implementation.

## Blocks and callbacks

A Ruby block is a live callable projection. A Rexx callback passed into Ruby is a retained Rexx projection whose Ruby call surface re-enters the resident interpreter. Nested Ruby → Rexx → Ruby and Rexx → Ruby → Rexx calls preserve identity.

## Native next boundary

dev2 should replace the abstract Rexx `rubyBridge` with the resident native package and implement:
* Ruby VM attach/ownership and thread/GVL rules;
* retained VALUE protection and Rexx global references;
* Ruby symbol/string selector mapping;
* positional + keyword arguments;
* blocks/Proc;
* structured exception capture (`rb_protect`);
* exact missing-vs-raised discrimination;
* reverse projection/unwrapping;
* deterministic release and shutdown ordering.


## dev2 executable native boundary

The first native package now retains Ruby `VALUE` objects with `rb_gc_register_address`, uses opaque numeric handles only as in-process references, performs real `rb_funcall` under `rb_protect`, and explicitly unregisters roots on release. The acceptance test runs this package from ooRexx and verifies `method_missing`, identity, and post-projection Ruby mutation.
