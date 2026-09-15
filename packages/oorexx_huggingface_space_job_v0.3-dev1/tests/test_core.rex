/* Credential mode is enforced by ooRexx/SysFileTree, not a stat subprocess. */
cred=.HFTokenCredential~new('huggingface.key')
v=cred~validate
if v<>"OK" then call fail "credential validation " || v
bad=.HFTokenCredential~new('bad.key')
bv=bad~validate
if left(bv,20)<>"TOKEN_MODE_MISMATCH:" then call fail '0644 token was not rejected: ' || bv

cpu=.HFSpaceJobRequirement~new('CPU')
if cpu~tier<>"CPU" | cpu~quotaCostSeconds<>0 then call fail 'CPU tier/cost'
large=.HFSpaceJobRequirement~new('GPU',49152,100)
if large~tier<>"ZEROGPU_LARGE" | large~quotaCostSeconds<>100 then call fail 'large tier/cost'
xl=.HFSpaceJobRequirement~new('GPU',49153,100)
if xl~tier<>"ZEROGPU_XLARGE" | xl~quotaCostSeconds<>200 then call fail 'xlarge tier/cost'

b=.HFZeroGpuQuotaBudget~new(2400,150,.false,'TEST')
q=b~reserve(large)
if \q~allowed | q~source<>"INCLUDED" | b~remainingIncludedSeconds<>50 then call fail 'included reservation'
q2=b~reserve(xl)
if q2~allowed | q2~code<>"ZEROGPU_INCLUDED_QUOTA_INSUFFICIENT" then call fail 'quota fail closed'
paidReq=.HFSpaceJobRequirement~new('GPU',60000,100,.true)
pb=.HFZeroGpuQuotaBudget~new(2400,0,.true,'TEST')
pq=pb~reserve(paidReq)
if \pq~allowed | pq~source<>"PAID_CREDITS" then call fail 'explicit paid spillover'
noPaid=.HFZeroGpuQuotaBudget~new(2400,0,.true,'TEST')
np=noPaid~reserve(xl)
if np~allowed then call fail 'job did not opt into paid credits'

route=.ApiRouteRequirement~new
t=.HFSpaceTarget~new('rexxapiai/rexxapi','https://localhost:18444',route)
if t~endpointFor(cpu)~name<>"job_cpu" then call fail 'CPU endpoint'
if t~endpointFor(large)~name<>"job_large" then call fail 'large endpoint'
if t~endpointFor(xl)~name<>"job_xlarge" then call fail 'xlarge endpoint'


/* Input names may not collide with provider control/payload planes. */
coll=.HFSpaceInputFile~new('_job','input.bundle')
if coll~parameterName<>'_job' then call fail 'input object construction'

ev=.HFSpaceEvidence~new~add('TEST','OK','Bearer hf_secret')
if pos('hf_secret',ev~canonical)>0 then call fail 'evidence leaked token'

say 'PASS HF SPACE CORE CREDENTIAL ZEROGPU QUOTA ENDPOINT POLICY'
exit 0
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'HuggingFaceSpaceJob.cls'
