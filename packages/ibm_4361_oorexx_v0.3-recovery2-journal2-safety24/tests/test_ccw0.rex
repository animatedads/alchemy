/* Format-0 CCW fields and architectural flag interpretation. */
a=.IBM370CCW0~new("0200020040000020")
call eq a~commandHex,"02","command"
call eq a~dataAddress,512,"data address"
call eq a~count,32,"count"
call truth a~commandChain,"command chaining"
call truth \a~dataChain,"no data chaining"
call truth \a~suppressLength,"no SLI"
call truth \a~skip,"no skip"

t=.IBM370CCW0~new("0800002000000000")
call truth t~isTIC,"TIC command"
call eq t~dataAddress,32,"TIC target"
say "PASS test_ccw0"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return
truth: procedure
  parse arg ok,label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return

::requires "IBM4361State.cls"
