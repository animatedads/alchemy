numeric digits 50
ctx=.MathContext~rational
A=.Maths~matrix(.array~of( -
  .array~of(.Maths~fraction(1,3),.Maths~fraction(1,2)), -
  .array~of(-1,0)),ctx)

say 'SOURCE'
say A
say

q=A~quantize(.MathQuantizationScheme~int8(4))
say 'INT8 state:' q~state~canonical
say 'INT8 exact max reconstruction error:' q~maxAbsError
say 'INT8 exact declared bound:' q~maxErrorBound
say 'INT8 dequantized:'
say q~dequantize(ctx)
say

p=q~prove(.MathClaim~quantizationErrorBelow('1/200'))
say 'claim <= 1/200:' p~outcome p~status

nf=A~quantize(.MathQuantizationScheme~nf4(4,'BFLOAT16'))
say 'NF4 state:' nf~state~canonical
say 'NF4 exact max reconstruction error:' nf~maxAbsError
say 'NF4 exact declared bound:' nf~maxErrorBound
say

plan=.Maths~mixedPrecision(.MathQuantizationScheme~nf4,4096,'FLOAT32')
plan~protect('BIAS')
plan~outliers(6)
say 'mixed precision:' plan~canonical

::requires 'MathsBootstrap.cls'
