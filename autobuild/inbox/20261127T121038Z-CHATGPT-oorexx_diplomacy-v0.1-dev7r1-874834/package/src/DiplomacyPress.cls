/* Architecture Tom Dyer. Implementation ChatGPT GPT-6.2.
   Step 6: private numeric address books, sealed round barrier and plain-text mail.
   All objects here are host-side. Player views contain only detached strings. */
::class DiplomacyPress public
::method init
  expose rng journal inboxes inboxOrder
  use strict arg seed, journal, inboxOrder = 'SORTED'
  if \.array~of('SORTED','SEEDED')~hasItem(inboxOrder) then raise syntax 93.900 array('Invalid inbox order policy')
  numeric digits 20
  rng = seed // 2147483646 + 1
  inboxes = .directory~new
::method beginMovement
  expose inboxes
  inboxes = .directory~new
::method draw
  expose rng
  use strict arg n
  numeric digits 20
  rng = (rng * 48271) // 2147483647
  return rng // n + 1
::method playerList
  expose rng journal
  use strict arg year, phase, round, sender, active
  list = active~copy
  before = rng
  do idx = list~items to 2 by -1
    pick = self~draw(idx)
    swap = list[idx]
    list[idx] = list[pick]
    list[pick] = swap
  end
  journal~record('PLAYER_LIST|'year'|'phase'|'round'|'sender'|'before'|'list~makeString('L',' '))
  return list
::method inbox
  expose inboxes
  use strict arg power
  if \inboxes~hasIndex(power) then return .array~new
  return inboxes[power]~copy
::method finishRound
  expose journal inboxes inboxOrder
  use strict arg year, phase, round, responses, lists
  -- This method runs only after every source call has returned. The old
  -- inboxes are never mutated during collection; new inboxes replace them.
  nextInbox = .directory~new
  groups = .directory~new
  sequence = 0
  season = phase~left(1)
  do sender over responses~allIndexes~sort
    reply = responses[sender]
    if reply[1] \== 'OK' then iterate
    parsed = self~parseMail(reply[2])
    journal~record('PRESS_PARSE|'year'|'phase'|'round'|'sender'|'parsed[1]'|'parsed[2]~items)
    if parsed[1] \== 'OK' then iterate
    messages = parsed[2]
    do idx = 1 to messages~items
      msg = messages[idx]
      if idx > 6 then do
        journal~record('MAIL_DROP|'year'|'phase'|'round'|'sender'|'idx'|MESSAGE_CAP')
        iterate
      end
      recipients = self~resolveRecipients(msg[1],lists[sender])
      if recipients~items = 0 then do
        journal~record('MAIL_DROP|'year'|'phase'|'round'|'sender'|'idx'|BAD_ADDRESS')
        iterate
      end
      capped = diplomacyMailCap(msg[2],1500)
      body = capped[1]
      if capped[2] > 1500 then journal~record('MAIL_CUT|'year'|'phase'|'round'|'sender'|'idx'|'capped[2]'|1500')
      injection = self~injectionMarker(body)
      sequence += 1
      id = year||season||'-R'||round||'-'||right(sequence,3,'0')
      toList = recipients~makeString('L',' ')
      journal~record('MAIL|'id'|'sender'|'toList'|'injection'|'body~c2x)
      frame = self~frame(id,sender,toList,body)
      do power over recipients
        if \nextInbox~hasIndex(power) then nextInbox[power] = .array~new
        if inboxOrder == 'SORTED' then nextInbox[power]~append(frame)
        else do
          if \groups~hasIndex(power) then groups[power] = .directory~new
          if \groups[power]~hasIndex(sender) then groups[power][sender] = .array~new
          groups[power][sender]~append(.array~of(id,frame))
        end
      end
    end
  end
  if inboxOrder == 'SEEDED' then do recipient over lists~allIndexes~sort
    ids = .array~new
    received = .array~new
    if groups~hasIndex(recipient) then do sender over lists[recipient]
      if \groups[recipient]~hasIndex(sender) then iterate
      do row over groups[recipient][sender]
        ids~append(row[1])
        received~append(row[2])
      end
    end
    nextInbox[recipient] = received
    journal~record('INBOX_ORDER|'year'|'phase'|'round'|'recipient'|'ids~makeString('L',' '))
  end
  inboxes = nextInbox
  journal~record('PRESS_END|'year'|'phase'|'round'|'sequence)
::method parseMail
  use strict arg raw
  -- Outside blocks is not interpreted. A recognised but incomplete SEND
  -- block makes the response unparseable atomically. Body lines are literal.
  messages = .array~new
  mode = 'OUTSIDE'
  bodyLines = .array~new
  address = ''
  normal = changestr('0D0A'x,raw,'0A'x)
  normal = changestr('0D'x,normal,'0A'x)
  do line over normal~makeArray('0A'x)
    token = line~strip~upper
    select
      when mode == 'BODY' then do
        if token == 'END MESSAGE' then do
          messages~append(.array~of(address,bodyLines~makeString('L','0A'x)))
          mode = 'OUTSIDE'
        end
        else bodyLines~append(line)
      end
      when mode == 'EXPECT_MESSAGE' then do
        if token \== 'MESSAGE:' then return .array~of('BAD_RESPONSE',.array~new)
        bodyLines = .array~new
        mode = 'BODY'
      end
      otherwise if token~left(8) == 'SEND TO:' then do
        address = line~strip~substr(9)~space
        mode = 'EXPECT_MESSAGE'
      end
    end
  end
  if mode \== 'OUTSIDE' then return .array~of('BAD_RESPONSE',.array~new)
  return .array~of('OK',messages)
::method resolveRecipients
  use strict arg address, list
  recipients = .directory~new
  do token over address~space~makeArray(' ')
    if token == '' then return .array~new
    if token~verify('0123456789') \= 0 then return .array~new
    number = token~strip('L','0')
    if number == '' then return .array~new
    if number~length > 1 then return .array~new
    if number > list~items then return .array~new
    recipients[list[number]] = .true
  end
  return recipients~allIndexes~sort
::method injectionMarker
  use strict arg body
  -- Observable syntactic metric, not an intent classifier or a filter.
  do line over body~makeArray('0A'x)
    token = line~strip~upper
    if token~left(3) == '===' then return 1
    if token~left(7) == 'SYSTEM:' then return 1
    if token~left(10) == 'FRAMEWORK:' then return 1
  end
  return 0
::method frame
  use strict arg id, sender, recipients, body
  lines = .array~new
  lines~append('=== MAIL' id 'FROM' sender 'TO' recipients '===')
  do line over (body||'0A'x)~makeArray('0A'x)
    if line~left(3) == '===' then line = '> '||line
    lines~append(line)
  end
  lines~append('=== END MAIL' id '===')
  return lines~makeString('L','0A'x)
::method module_version class
  return '0.1-dev7r1'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine diplomacyMailCap public
  -- ooRexx strings are bytes. Count valid UTF-8 code points without splitting
  -- multibyte sequences. Invalid bytes are retained as individual characters.
  use strict arg body, limit
  n = 0
  boundary = 0
  idx = 1
  do while idx <= body~length
    b = body~substr(idx,1)~c2d
    width = 1
    select
      when b >= 194 & b <= 223 then width = 2
      when b >= 224 & b <= 239 then width = 3
      when b >= 240 & b <= 244 then width = 4
      otherwise nop
    end
    if idx + width - 1 > body~length then width = 1
    if width > 1 then do
      do offset = 1 to width - 1
        continuation = body~substr(idx+offset,1)~c2d
        if continuation < 128 | continuation > 191 then do
          width = 1
          leave
        end
      end
      if width > 1 then do
        second = body~substr(idx+1,1)~c2d
        if b = 224 & second < 160 then width = 1
        if b = 237 & second > 159 then width = 1
        if b = 240 & second < 144 then width = 1
        if b = 244 & second > 143 then width = 1
      end
    end
    n += 1
    idx += width
    if n <= limit then boundary = idx - 1
  end
  return .array~of(body~left(boundary),n)
