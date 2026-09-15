lib=.foreign~load('../examples/test-names.bridge.json')
if lib~invoke('add',19,23) \= 42 then do
  say 'FAIL library candidate fallback'
  exit 1
end
say 'PASS library candidate fallback'
lib~close
exit 0
::requires '../rexx/foreign.cls'
