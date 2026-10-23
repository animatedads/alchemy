call rxfuncadd 'sysloadfuncs', 'rexxutil', 'sysloadfuncs'
::requires 'AlchemyProlog.cls'
r = .AlchemyPrologRuntime~new
say 'SWI-Prolog:' r~version
e = r~engine
/* Ground query proof.  Logical-variable projection follows in dev2. */
q = e~query('user', 'atom', .array~of('alchemy'))
answer = q~nextSolution
if answer == .nil then say 'FAIL'
else say 'SUCCESS:' answer[1]
q~close
e~close
