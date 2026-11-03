numeric digits 50
ctx=.MathContext~decimal(50)
A=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)),ctx)
b=.Maths~vector(.array~of(5,5),ctx)
x=A~solve(b)
claim=.MathClaim~satisfiesEquation('1E-45')

say '--- STANDARD ---'
say x~prove(claim,.nil,.MathProofPolicy~standard)~describe
say
say '--- CERTIFIED ---'
say x~prove(claim,.nil,.MathProofPolicy~certified)~describe
say
say '--- STRONG ---'
say x~prove(claim,.nil,.MathProofPolicy~strong)~describe

::requires '../rexx/MathsBootstrap.cls'
