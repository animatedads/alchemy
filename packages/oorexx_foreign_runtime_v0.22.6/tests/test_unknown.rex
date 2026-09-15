lib=.foreign~load('../examples/test.bridge.json')
signal on syntax name expectedUnknown
ignored=lib~definitely_not_in_metadata(1,2,3)
say 'FAIL unknown foreign method did not raise syntax'
lib~close
exit 1
expectedUnknown:
  lib~close
  say 'PASS metadata-gated UNKNOWN rejects undefined method'
  exit 0
::requires '../rexx/foreign.cls'
