/* HeelTurnFixture.cls - build call text from the framework's own rendering.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
::class HeelTurnFixture public
::method init
  expose system input
  use strict arg path
  s = .stream~new(path)
  if s~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read fixture' path)
  t = s~charin(1, s~chars)
  s~close
  at = pos('=== RULES ===', t)
  system = t~left(at - 1)~strip('T', '0A'x)
  input = t~substr(at)
::method system
  expose system
  use strict arg prompt = ''
  if prompt == '' then return system
  return system~left(pos('0A0A'x, system) + 1) || prompt
::method input
  -- mails: array of 'ID|FROM|TO|body'; results: array of 'year|phase|power|status|line';
  -- memory: array of lines; kind/power/phase replace the state and task lines.
  expose input
  use strict arg mails = (.array~new), results = (.array~new), memory = (.array~new), kind = 'PRESS', phase = 'SPRING_MOVEMENT', power = 'AUS'
  t = input
  inbox = ''
  do m over mails
    parse var m mid '|' from '|' to '|' body
    inbox = inbox || '=== MAIL' mid 'FROM' from 'TO' to '===' || '0A'x || body || '0A'x || '=== END MAIL' mid '===' || '0A'x
  end
  t = t~changestr('=== INBOX ===' || '0A'x, '=== INBOX ===' || '0A'x || inbox)
  res = ''
  do r over results
    parse var r ry '|' rp '|' rpow '|' rst '|' rline
    res = res || ry'|'rp'|'rpow'|'rst || '0A'x || '> 'rline || '0A'x
  end
  t = t~changestr('=== LAST RESULTS ===' || '0A'x, '=== LAST RESULTS ===' || '0A'x || res)
  mem = ''
  do line over memory
    mem = mem || '> 'line || '0A'x
  end
  t = t~changestr('=== MEMORY ===' || '0A'x || '> ' || '0A'x, '=== MEMORY ===' || '0A'x || mem)
  t = t~changestr('1901 SPRING_MOVEMENT POWER AUS', '1901' phase 'POWER' power)
  t = t~changestr('PRESS POWER AUS BALANCE 0', kind 'POWER' power 'BALANCE 0')
  return t
::method module_version class
  return '0.1r4'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
