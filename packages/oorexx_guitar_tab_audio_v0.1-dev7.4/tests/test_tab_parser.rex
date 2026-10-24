lines=.array~of('e|----|','B|----|','G|----|','D|----|','A|0h2-|','E|0-x-|')
ev=.AsciiTabParser~parse(lines)
if ev~items<>4 then do; say 'FAIL event count' ev~items; exit 1; end
if ev[1]~stringNumber<>5 | ev[1]~fret<>0 then do; say 'FAIL first event'; exit 1; end
foundHammer=.false; foundMute=.false
do e over ev
  if e~articulation='HAMMER' then foundHammer=.true
  if e~kind='DEAD' then foundMute=.true
end
if \foundHammer then do; say 'FAIL hammer'; exit 1; end
if \foundMute then do; say 'FAIL mute'; exit 1; end
say 'TAB PARSER: OK'
exit 0
::requires 'AsciiTab.cls'
