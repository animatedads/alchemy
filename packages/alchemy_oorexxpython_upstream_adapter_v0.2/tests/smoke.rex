/* A fresh Rexx-hosted process; upstream bridge must be installed. */
p = .AlchemyPythonAdapter~import("builtins")
if p~len("abc") <> 3 then exit 1
if .AlchemyPythonAdapter~evaluate("6 * 7") <> 42 then exit 2
if .AlchemyPythonAdapter~pythonType("abc")~__name__ <> "str" then exit 3
say "ALCHEMY-UPSTREAM-REXX-PASS"
::requires "AlchemyPythonAdapter.cls"
