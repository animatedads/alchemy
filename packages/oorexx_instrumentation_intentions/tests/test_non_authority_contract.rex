collector=.InstrumentationCollector~new(4)
p=.InstrumentationIntentionProvider~new(collector)
s=p~discover(.Directory~new)
if s['mutating']<>.false then do; say 'FAIL mutating surface'; exit 1; end
if p~hasMethod('HANDLECOMMAND') then do; say 'FAIL provider exposes command'; exit 1; end
if p~readAuthority~hasMethod('HANDLECOMMAND') then do; say 'FAIL read authority exposes command'; exit 1; end
say 'PASS test_non_authority_contract'
exit 0
::requires '../src/InstrumentationIntentions.cls'
