now = .DateTime~new
span = .SecurityCanonical~timeSpanSeconds(3600)
call assertEqual 3600,span~totalSeconds,'3600-second helper is one hour'
subject = 'CUSTOMER-TIME'
reportTime = now - .TimeSpan~new(0,0,10,0,0)
call assertEqual 600,(now - reportTime)~totalSeconds,'Barbie canonical case is really ten minutes old'
londonTime = now - .TimeSpan~new(0,0,30,0,0)
call assertEqual 1800,(now - londonTime)~totalSeconds,'Kazakhstan canonical case is really thirty minutes after London'
say 'PASS test_time_semantics'
exit 0
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffect.cls'
