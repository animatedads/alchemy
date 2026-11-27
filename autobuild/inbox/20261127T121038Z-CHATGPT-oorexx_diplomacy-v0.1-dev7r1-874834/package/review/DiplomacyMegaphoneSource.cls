/* Megaphone measurement player for the step-6 press controller.
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Not a strategy. Every unit holds, so the board never depends on press.
   Press profile per power:
     LOUD  - six messages, each of the 1500 code point cap, to every other power
     QUIET - one short message to every other power
   Every movement order call and every press call measures the INBOX it is
   shown: which sender's mail sits at which rank, and how many bytes came
   from each sender. */
::requires 'DiplomacyGame.cls'
::class DiplomacyMegaphoneSource public
::method init
  expose loud filler stats
  use strict arg loud
  stats = .directory~new
  text = ''
  do while text~length < 1500
    text ||= 'Megaphone filler sentence for volume measurement only. '
  end
  filler = text~left(1500)
::method stats
  expose stats
  return stats
::method orders
  use strict arg view
  out = .array~new
  if view['KIND'] == 'MOVEMENT' then do
    self~measure('ORDER', view['POWER'], view['INBOX'])
    do item over view['TASK']
      out~append(item 'H')
    end
  end
  else if view['KIND'] == 'RETREAT' then do
    do item over view['TASK']
      out~append(item 'D')
    end
  end
  else if view['KIND'] == 'ADJUSTMENT' then do
    balance = view['BALANCE']
    if balance < 0 then do idx = 1 to -balance
      if idx <= view['TASK']~items then out~append('DISBAND' view['TASK'][idx])
    end
    else do idx = 1 to balance
      out~append('WAIVE')
    end
  end
  return .array~of('OK',out)
::method press
  expose loud filler
  use strict arg view
  self~measure('PRESS', view['POWER'], view['INBOX'])
  list = view['PLAYER_LIST']
  others = ''
  do idx = 1 to list~items
    if list[idx] \== view['POWER'] then others = others idx
  end
  others = others~strip
  if others == '' then return .array~of('OK','')
  lf = '0A'x
  if wordpos(view['POWER'], loud) > 0 then do
    count = 6
    body = filler
  end
  else do
    count = 1
    body = 'quiet note'
  end
  raw = ''
  do idx = 1 to count
    raw ||= 'SEND TO:' others || lf || 'MESSAGE:' || lf || body || lf || 'END MESSAGE' || lf
  end
  return .array~of('OK',raw)
::method measure
  expose stats
  use strict arg callKind, recipient, inbox
  -- Rank counts distinct senders other than the recipient, in inbox order.
  rank = 0
  seen = .directory~new
  do frame over inbox
    header = frame~makeArray('0A'x)[1]
    parse var header '=== MAIL ' . ' FROM ' sender ' TO ' .
    bytes = frame~length
    self~add(callKind, sender, 'BYTES', bytes)
    self~add(callKind, recipient, 'RECEIVED', bytes)
    if sender == recipient then iterate
    if seen~hasIndex(sender) then iterate
    seen[sender] = .true
    rank += 1
    self~add(callKind, sender, 'RANKSUM', rank)
    self~add(callKind, sender, 'RANKN', 1)
    if rank = 1 then self~add(callKind, sender, 'FIRST', 1)
    self~add(callKind, sender, 'LASTCANDIDATE', 0)
  end
  if rank > 0 then do
    -- The last distinct sender in this inbox read last before the reply.
    last = ''
    do frame over inbox
      header = frame~makeArray('0A'x)[1]
      parse var header '=== MAIL ' . ' FROM ' sender ' TO ' .
      if sender \== recipient then last = sender
    end
    self~add(callKind, last, 'LAST', 1)
  end
  self~add(callKind, recipient, 'INBOXES', 1)
::method add
  expose stats
  use strict arg callKind, power, field, amount
  key = callKind'|'power'|'field
  if \stats~hasIndex(key) then stats[key] = 0
  stats[key] = stats[key] + amount
::method complete
  return
::method module_version class
  return '0.1'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
