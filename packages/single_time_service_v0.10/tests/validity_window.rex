::requires 'TimeValidityWindow.cls'
num=0
svc=.TimeValidityWindow~new
n=.TimeClockInterval~new(100,105,'controlled-clock','POLICY_AUTHORISED')
r=svc~assess(90,110,n)
call test r['status']='INSIDE_TIME_WINDOW','entirely valid'
call test r['timeCriterionSatisfied']=.true,'authorised clock sufficient for time check'
call test r['authorisesUse']=.false,'never authorise certificate use'
r=svc~assess(106,120,n)
call test r['status']='DEFINITELY_TOO_EARLY','too early'
r=svc~assess(0,100,n)
call test r['status']='DEFINITELY_EXPIRED','expired exclusive'
r=svc~assess(102,120,n)
call test r['status']='INDETERMINATE','uncertainty crosses notBefore'
r=svc~assess(0,103,n)
call test r['status']='INDETERMINATE','uncertainty crosses notAfter'
other=.TimeClockInterval~new(100,105,'unverified-clock')
r=svc~assess(90,110,other)
call test r['timeCriterionSatisfied']=.false,'unverified evidence cannot pass even the time gate'
say 'PASS validity window checks:' num
exit 0
test:
  parse arg works, explanation
  if \works then do
    say 'FAIL:' explanation
    exit 1
  end
  num=num+1
  return
