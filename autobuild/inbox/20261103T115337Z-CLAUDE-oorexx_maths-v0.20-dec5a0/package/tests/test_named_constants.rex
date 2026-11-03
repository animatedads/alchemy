parse source . . here
base=filespec('location',here)
call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'
call SysLoadFuncs
fails=0; tests=0
ctx30=.MathContext~decimal(30)
ctx70=.MathContext~decimal(70)

call assertEq .Maths~namedConstant('pi',ctx30), .Maths~pi(ctx30), 'named PI equals pi alias'
call assertTrue .Maths~namedConstant('PI',ctx30)==.Maths~namedConstant('pi',ctx30), 'case-insensitive cached lookup'
p30=.Maths~namedConstant('pi',ctx30)~string
p70=.Maths~namedConstant('pi',ctx70)~string
call assertTrue p70~length>=p30~length, 'higher precision context is not narrowed to lower precision cache entry'
call assertTrue p30~left(16)='3.14159265358979', 'pi prefix'

say tests-fails'/'tests 'executed assertions PASS'
if fails>0 then exit 1
exit 0

assertEq: procedure expose fails tests
tests+=1
use arg actual,expected,label
if actual==expected then return
fails+=1; say 'FAIL:' label 'actual='actual 'expected='expected
return

assertTrue: procedure expose fails tests
tests+=1
use arg condition,label
if condition then return
fails+=1; say 'FAIL:' label
return

::requires 'MathsBootstrap.cls'
