numeric digits 50
installed=.CryptoForeignRuntimeInstaller~install
failures=0
A=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)))
B=.Maths~matrix(.array~of(.array~of(5,6),.array~of(7,8)))
C=A*B
seal=.MathEvidenceSealer~sha256(C~evidence)
call check seal~digest~length=64,'SHA-256 evidence seal length'
call check .MathEvidenceSealer~verify(C~evidence),'SHA-256 evidence seal verifies'
C~evidence~putCheck('tamper','yes')
call check \.MathEvidenceSealer~verify(C~evidence),'evidence mutation invalidates seal'

S=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)))
b=.Maths~vector(.array~of(5,5))
x=S~solve(b)
proof=x~prove(.MathClaim~satisfiesEquation('1E-45'),.nil,'STRONG')
pseal=.MathProofSealer~sha256(proof)
call check pseal~digest~length=64,'SHA-256 proof seal length'
call check .MathProofSealer~verify(proof),'SHA-256 full proof seal verifies'
proof~checks['postSealMutation']='yes'
call check \.MathProofSealer~verify(proof),'proof-plan/check mutation invalidates full proof seal'
if failures=0 then do; say 'PASS oorexx_maths crypto evidence 6 assertions'; exit 0; end
say 'FAIL oorexx_maths crypto evidence failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathCryptoEvidence.cls'

::requires 'CryptoForeignRuntimeProvider.cls'
