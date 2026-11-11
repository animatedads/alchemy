/* Long unaliased expression -> long column name -> varname buffer. Claude (Opus 5.5). */
call rxfuncadd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'; call SQLLoadFuncs
call SQLConnect 'c1',,,':memory:'
expr = "'a'" || copies(" || 'a'", 60)
rc = SQLCommand('q', 'select' expr)
say 'rc=' rc sqlca.sqlerrm
say 'survived'
