lib=.foreign~load('../examples/test.bridge.json')
t=.CallbackTarget~new
cb=lib~callback('binary_i32',t,'sum')
say 'DEV12 policy='cb~threadPolicy 'lifetime='cb~lifetime
v=lib~callback_apply(cb,20,22)
say 'DEV12 callbackResult='v
if v<>42 then exit 2
cb~close
lib~close
say 'DEV12 PASS'
exit 0

::class CallbackTarget
::method sum
  use strict arg a,b
  return a+b

::requires '../rexx/foreign.cls'
