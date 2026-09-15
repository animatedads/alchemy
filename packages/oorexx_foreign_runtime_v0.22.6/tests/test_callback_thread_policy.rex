lib=.foreign~load('../examples/test.bridge.json')
t=.CallbackTarget~new
cb=lib~callback('binary_i32',t,'sum')
signal on syntax name rejected
ignored=lib~callback_apply_other_thread(cb,20,22)
say 'FAIL cross-thread callback was not rejected'
cb~close; lib~close
exit 1
rejected:
  cb~close; lib~close
  say 'PASS cross-thread callback rejected by call-thread policy'
  exit 0
::class CallbackTarget
::method sum
  use strict arg a,b
  return a+b
::requires '../rexx/foreign.cls'
