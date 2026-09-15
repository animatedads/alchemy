/* A syntactically valid modified architectural record must fail the digest. */
path="/tmp/ibm4361-tamper.state"
bad="/tmp/ibm4361-tamper-bad.state"
m=.IBM4361Machine~new(1048576)
m~powerOn
records=.array~of("0008000000001000"||"0200020000000004"||"0000000000000000","CAFEBABE")
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"TAMPER","fixture-v2")
m~attachDevice(d)
m~initialProgramLoad(x2d("148"))
m~cpu~setGpr(3,123)
.IBM4361State~new~save(m,path)

src=.stream~new(path); ignored=src~open("READ")
dst=.stream~new(bad); ignored=dst~open("WRITE REPLACE")
changed=0
do while src~lines>0
  line=src~linein
  if \changed & line~left(5)="GPR 3" then do
    line="GPR 3 124"
    changed=1
  end
  ignored=dst~lineout(line)
end
ignored=src~close; ignored=dst~close
if \changed then do
  say "FAIL tamper fixture did not alter GPR"
  exit 1
end
signal on syntax name expected
x=.IBM4361State~new~load(bad)
say "FAIL tampered state was accepted"
exit 1
expected:
  call sysFileDelete path
  call sysFileDelete bad
  say "PASS test_state_tamper_rejected"
  exit 0

::requires "IBM4361State.cls"
