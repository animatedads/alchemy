numeric digits 50
x=.Maths~variable('x')
expr=(x*2)-(x*2)
claim=.MathClaim~equals(0)
proof=expr~prove(claim)
say 'expression:' expr
say 'proof outcome:' proof~outcome
say 'proof strength:' proof~status
say 'simplified difference:' proof~checks['simplifiedDifference']

bounds=.directory~new; bounds['x']=.array~of('0','1')
iv=expr~interval(bounds)
ip=iv~prove
say 'interval:' iv
say 'interval width:' iv~width
say 'interval claim:' ip~claim~kind
say 'interval proof:' ip~outcome ip~status
::requires '../rexx/MathProofProviders.cls'
