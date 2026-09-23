numeric digits 30
parse arg bridge
if bridge='' then do; say 'FAIL bridge path required'; exit 2; end
lib=.foreign~load(bridge)
if lib==.nil then do; say 'FAIL spatial foreign load returned nil'; exit 2; end
say 'PASS spatial-native load'
exit 0
::requires 'foreign.cls'
