/* Android embedded ooRexx qualification.
   No Wire dependency: prove the interpreter boundary first. */
x = 'ok'
a.1 = 'one'
if x <> 'ok' | a.1 <> 'one' then return 'OO REXX COMPOUND FAIL'
return 'OO REXX WORKS'
