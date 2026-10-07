lib=.foreign~load('/mnt/data/oorexx_pharo_alchemy_v0.1-dev13-combined-reentry/tests/dev13.bridge.json')
t=.Dev13Target~new
cb=lib~callback('binary_i32',t,'sum')
say 'DEV13 rexxCallbackPolicy='cb~threadPolicy 'lifetime='cb~lifetime
v=lib~cross(cb,20,22)
say 'DEV13 rexxNestedResult='v
if v<>42 then exit 2
cb~close
lib~close
exit 0

::class Dev13Target
::method sum
  use strict arg a,b
  say 'DEV13 retainedRexxSum=' a '+' b
  return a+b

::requires 'foreign.cls'
