numeric digits 50
failures=0
ctx=.MathContext~rational

call check .Maths~dtype('int8')~bits=8 & .Maths~dtype('int8')~exact,'INT8 dtype is explicit exact integer storage type'
call check .Maths~dtype('bfloat16')~bits=16 & \.Maths~dtype('bfloat16')~exact,'BFLOAT16 dtype is explicit approximate binary compute type'

int8=.MathQuantizationScheme~int8(4,'FLOAT32')
call check int8~name='SYMMETRIC_INT8' & int8~bits=8 & int8~blockSize=4,'symmetric INT8 scheme records bits and block size'
call check int8~rounding='NEAREST_EVEN' & int8~computeType~name='FLOAT32','INT8 scheme records rounding and compute dtype'

nf4=.MathQuantizationScheme~nf4(4,'BFLOAT16')
call check nf4~name='NF4' & nf4~codebook~size=16,'NF4 scheme retains explicit 16-value codebook'
call check nf4~codebook~at(8)=0 & nf4~codebook~at(1)=-1 & nf4~codebook~at(16)=1,'NF4 codebook retains zero and normalized endpoints exactly'
call check nf4~providerHint='BITSANDBYTES-CONCEPT','NF4 scheme records bitsandbytes conceptual lineage without provider lock-in'
call check expectNestedReject(),'PURE reference quantizer fails closed rather than pretending to implement nested/double quantization'

A=.Maths~matrix(.array~of( -
  .array~of(.Maths~fraction(1,3),.Maths~fraction(1,2)), -
  .array~of(-1,0)),ctx)
q=A~quantize(int8)
call check q~isA(.MathQuantizedMatrix),'matrix~quantize returns first-class quantized matrix object'
call check q~rows=2 & q~cols=2 & q~payload~items=4,'quantized matrix retains shape and integer payload'
call check q~state~scales~items=1 & q~state~provider='PURE','quantized state retains block scales and provider'
call check q~state~scheme~canonical=int8~canonical,'quantized state retains complete scheme'
call check q~evidence~steps[1]~guarantee='LOSSY_EXACTLY_CHARACTERIZED_OVER_REPRESENTED_VALUES','INT8 evidence states scoped lossy guarantee'
call check q~evidence~checks['errorScope']='retained represented source values','quantization evidence states exact error scope'
call check q~maxAbsError=.Maths~fraction(1,254),'INT8 exact replay exposes exact maximum reconstruction error'
call check q~maxErrorBound=.Maths~fraction(1,254),'INT8 nearest-even block bound is retained exactly'

dq=q~dequantize(ctx)
call check dq~isA(.MathMatrix) & dq~context~numberDomain='RATIONAL','dequantization can reconstruct into exact rational context'
call check dq[2,1]=-1 & dq[2,2]=0,'INT8 block endpoints and zero reconstruct exactly'
call check dq~evidence~steps[1]~algorithm='stateful-dequantization','dequantization records its own stateful path'

p=q~prove(.MathClaim~quantizationErrorBelow('1/200'))
call check p~outcome='PROVED' & p~status='EXACT_BOUND_CERTIFIED','quantized object proves a satisfied reconstruction-error claim exactly'
call check p~checks['actualMaxAbsError']='1/254','quantization proof exposes exact observed maximum error'
pfail=q~prove(.MathClaim~quantizationErrorBelow('1/1000'))
call check pfail~outcome='DISPROVED' & pfail~status='BOUND_EXCEEDED','quantized object disproves an over-tight error claim'

/* Block size is mathematically significant: isolate a large outlier and a small
 * value into separate blocks and the small value can be represented exactly. */
v=.Maths~vector(.array~of(1,100),ctx)
qwide=v~quantize(.MathQuantizationScheme~int8(2))
qsplit=v~quantize(.MathQuantizationScheme~int8(1))
call check qwide~maxAbsError>0,'shared INT8 block exposes outlier-induced reconstruction error'
call check qsplit~maxAbsError=0,'one-value blocks isolate outlier and reconstruct both represented values exactly'
call check qsplit~state~scales~items=2,'blockwise state retains one exact scale per block'

qn=A~quantize(nf4)
call check qn~isA(.MathQuantizedMatrix) & qn~payload~items=4,'NF4 reference path creates quantized matrix payload'
call check qn~evidence~steps[1]~guarantee='LOSSY_EXACTLY_CHARACTERIZED_AGAINST_DECLARED_NF4_CODEBOOK','NF4 evidence scopes guarantee to declared codebook'
call check qn~maxAbsError>0 & qn~maxAbsError<=qn~maxErrorBound,'NF4 exact replay error lies within exact codebook cell bound'
call check qn~dequantize(ctx)[2,1]=-1 & qn~dequantize(ctx)[2,2]=0,'NF4 normalized endpoints and zero reconstruct exactly'
np=qn~prove(.MathClaim~quantizationErrorBelow(qn~maxErrorBound))
call check np~outcome='PROVED' & np~status='EXACT_BOUND_CERTIFIED','NF4 reference object certifies its represented-value error bound'

/* Quantized matrices remain mathematically usable: operations dequantize through
 * an explicit path rather than pretending the payload itself is an exact matrix. */
x=.Maths~vector(.array~of(1,1),ctx)
y=q*x
call check y~isA(.MathVector) & y~size=2,'quantized matrix overloaded * remains usable through explicit dequantization'

if failures=0 then do; say 'PASS oorexx_maths quantization 31 assertions'; exit 0; end
say 'FAIL oorexx_maths quantization failures='failures; exit 1
expectNestedReject: procedure
  signal on syntax name caughtNested
  v=.Maths~vector(.array~of(1,2,3))
  ignored=v~quantize(.MathQuantizationScheme~nf4(2,'BFLOAT16',.true))
  return .false
caughtNested:
  return .true

check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
