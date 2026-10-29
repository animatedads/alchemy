/* Optional Reasoned Thought / Maths cross-pillar conformance test.
 * No belief semantics are delegated to Maths. */
signal on syntax name onSyntax
failures=0

policy=.MathsEvidenceTierPolicy~new
r=policy~verifyEvidenceClasses
call check r['ok'],'Reasoned Thought evidence ranks match Maths finite chain'
call check r['mismatches']~items=0,'no rank drift reported'
call check policy~rank('stylometric')=1,'case-normalized bottom rank'
call check policy~rank('PROVENANCE')=4,'top rank'
call check policy~compare('TESTIMONY','DOCUMENTARY')=-1,'declared ordinal comparison'
call check policy~max('TESTIMONY','PROVENANCE')='PROVENANCE','max is higher declared tier'
call check policy~min('DOCUMENTARY','STYLOMETRIC')='STYLOMETRIC','min is lower declared tier'
call check r['scope']='ORDER_CONFORMANCE_ONLY','adapter scope remains mathematical'
call check r['semanticAuthority']='REASONED_THOUGHT','semantic authority remains Reasoned Thought'

if failures=0 then do
  say 'PASS Reasoned Thought / Maths tier conformance 9 assertions'
  exit 0
end
say 'FAIL Reasoned Thought / Maths tier conformance failures='failures
exit 1

check: procedure expose failures
  use arg ok,label
  if ok then do; say 'PASS' label; return; end
  failures+=1
  say 'FAIL' label
  return

onSyntax:
  say 'SYNTAX line' sigl ':' condition('D')
  exit 2

::requires 'MathsEvidenceTierPolicy.cls'
