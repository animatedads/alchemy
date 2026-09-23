# dev10 — Tcl_Obj value-vector dispatch

dev10 removes script concatenation from the new command/TclOO invocation path.

Each command name, method name and argument is converted independently with `Tcl_NewStringObj`, then dispatched with `Tcl_EvalObjv`. Tcl therefore receives values, not a string which must be reparsed as Tcl source. Spaces, braces, semicolons, newlines, `$` substitutions and `[...]` command substitutions remain literal argument content.

This is the first Tcl_Obj codec seam. It intentionally covers synchronous string-valued crossings first. Typed Tcl internal representations, byte arrays, lists/dicts, multiple arguments and durable Tcl_Obj identity are subsequent codec layers.

The old bounded dev9 call remains for regression compatibility; new bridge composition should use the Obj-vector path.
