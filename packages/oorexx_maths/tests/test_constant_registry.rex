parse source . . here
base=filespec('location',here)
call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'
call SysLoadFuncs
fails=0; tests=0
ctx30=.MathContext~decimal(30)
ctx70=.MathContext~decimal(70)
rat=.MathContext~rational

names=.Maths~constantNames
call assertEq names~items,9,'registry publishes nine foundational constants'
call assertTrue .Maths~hasNamedConstant('pi'),'PI is published'
call assertTrue .Maths~hasNamedConstant('phi'),'PHI alias resolves'
call assertTrue \ .Maths~hasNamedConstant('not-a-constant'),'unknown name is absent'

info=.Maths~constantInfo('phi')
call assertEq info['name'],'GOLDENRATIO','alias metadata resolves canonical name'
call assertEq info['kind'],'EXACT_DERIVATION','golden ratio retains derivation kind'
call assertEq .Maths~namedConstant('zero',rat)~string,'0','zero works in exact rational context'
call assertEq .Maths~namedConstant('one',rat)~string,'1','one works in exact rational context'
i=.Maths~namedConstant('i',rat)
call assertTrue i~isA(.MathComplex),'imaginary unit is a complex mathematical object'
call assertEq i~real,0,'imaginary unit real component'
call assertEq i~imaginary,1,'imaginary unit imaginary component'

pi=.Maths~namedConstant('pi',ctx30)
tau=.Maths~namedConstant('tau',ctx30)
call assertTrue (tau-(2*pi))~abs < 1E-28,'tau derives from pi'
e=.Maths~namedConstant('e',ctx30)~string
call assertTrue e~left(16)='2.71828182845904','e prefix'
g=.Maths~namedConstant('eulerMascheroni',ctx30)~string
call assertTrue g~left(16)='0.57721566490153','Euler-Mascheroni prefix'
phi=.Maths~namedConstant('goldenRatio',ctx30)~string
call assertTrue phi~left(16)='1.61803398874989','golden ratio prefix'
s2=.Maths~namedConstant('sqrt2',ctx30)~string
call assertTrue s2~left(16)='1.41421356237309','sqrt2 prefix'
call assertTrue .Maths~namedConstant('PHI',ctx70)==.Maths~namedConstant('goldenRatio',ctx70),'aliases share context cache entry'
call assertEq .Maths~constantInfo('gamma0')['name'],'EULERMASCHERONI','gamma0 alias metadata'

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
