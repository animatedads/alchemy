/* numeric_context.rex -- prove numeric settings belong to Rexx activities */
call contextWorker "A", 9, 0, "SCIENTIFIC"
call contextWorker "B", 30, 3, "ENGINEERING"

/* Main activity gets its own context and must not inherit worker settings. */
numeric digits 18
numeric fuzz 2
numeric form scientific
say "main-context:" digits()":"fuzz()":"form()
say "main-one-third:" 1 / 3
say "NUMERIC ACTIVITY CONTEXT POC PASS"
exit

contextWorker: procedure
  use arg label, d, f, formName
  numeric digits d
  numeric fuzz f
  if formName == "ENGINEERING" then numeric form engineering
  else numeric form scientific
  say "worker-"label"-context:" digits()":"fuzz()":"form()
  say "worker-"label"-one-third:" 1 / 3
  return
