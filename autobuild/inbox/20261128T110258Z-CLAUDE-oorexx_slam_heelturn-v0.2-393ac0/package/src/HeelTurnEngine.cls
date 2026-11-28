/* HeelTurnEngine.cls - Heel Turn SLAM: the runner face.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   The same face as DiplomacyEngine: invoke(system, input) returns a
   directory STATUS TEXT INPUT_TOKENS OUTPUT_TOKENS, and profile~identity
   names the runner. DiplomacyPlayer, press and the referee are unchanged;
   Heel Turn gets exactly the text a Haiku or Sol runner gets and answers
   in the same blocks (SEND / ORDERS / MEMORY). Each call is fresh: what it
   carries forward is only what it wrote in its own MEMORY block.
   Token counts are the SLAM unit's processing time (Tom Dyer, 27 Nov 2026:
   "total slam processing time used, so effectively workload over the slam
   unit"): INPUT_TOKENS is microseconds spent reading (board, prompt, mail,
   beliefs), OUTPUT_TOKENS microseconds spent planning and writing. Their sum,
   which the competition tie-break already adds, is the call's workload. The
   profile identity names the unit (us). Times go only to the framework's
   operator audit, never into the replay journal or the Heel Turn log, so
   replay stays byte-identical. */
::requires 'HeelTurnMind.cls'
::requires 'HeelTurnLog.cls'

::class HeelTurnProfile public
::attribute provider get
::attribute model get
::method init
  expose provider model
  provider = 'SLAM'
  model = 'heelturn-' || .HeelTurnEngine~module_version
::method identity
  expose provider model
  return provider'|'model'|deterministic|us|0'
::method module_version class
  return .HeelTurnEngine~module_version
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::class HeelTurnEngine public
::attribute profile get
::attribute vocab get
::method init
  expose profile vocab log
  use strict arg dataDir, logPath = '', progress = .false
  profile = .HeelTurnProfile~new
  vocab = .HeelTurnVocabulary~new(dataDir)
  log = .HeelTurnLog~new(logPath, progress)
::method log
  expose log
  return log
::method invoke
  expose log readMicros
  use strict arg system, input
  reply = .directory~new
  readMicros = 0
  started = .DateTime~new
  signal on syntax name engineFault
  text = self~think(system, input)
  signal off syntax
  total = heelTurnMicros(started)
  reply['STATUS'] = 'OK'
  reply['TEXT'] = text
  reply['INPUT_TOKENS'] = min(readMicros, total)
  reply['OUTPUT_TOKENS'] = total - min(readMicros, total)
  return reply
engineFault:
  fault = condition('O')
  trace = ''
  if fault \== .nil then if fault~hasIndex('TRACEBACK') then trace = fault['TRACEBACK']~makeString('L', ' / ')
  say 'HeelTurnEngine fault: rc='rc 'line='sigl condition('C') condition('D') trace
  log~say('FAULT|'rc'|'sigl'|'condition('C')'|'condition('D')'|'trace)
  reply['STATUS'] = 'ERROR'
  reply['TEXT'] = ''
  reply['INPUT_TOKENS'] = '-'
  reply['OUTPUT_TOKENS'] = '-'
  return reply
::method think
  expose vocab log readMicros
  use strict arg system, input
  thinkStarted = .DateTime~new
  view = .HeelTurnView~new(system, input)
  map = .HeelTurnMap~new(view~mapLines)
  places = .HeelTurnPlaces~new(view~mapLines)
  promptReader = .HeelTurnPromptReader~new(.HeelTurnReader~new(vocab))
  policy = promptReader~read(view~prompt)
  a = .HeelTurnAssessment~new(map, view)
  log~say('CALL|'view~year'|'view~phase'|'view~me'|'view~kind'|round='view~round'/'view~rounds)
  log~say('PROMPT|read='policy~readCount'|notread='policy~notRead~items'|'policy~summary)
  do nr over policy~notRead
    log~say('PROMPT_NOT_READ|'nr)
  end
  log~say('ASSESS|'a~summary)
  mind = .HeelTurnMind~new(view~memory, view, map, a, policy, vocab~testimony)
  mind~verify(view~results)
  readings = .array~new
  if view~mail~items > 0 then do
    mr = .HeelTurnMessageReader~new(.HeelTurnReader~new(vocab, places), map, a)
    do frame over view~mail
      r = mr~readMail(frame)
      readings~append(r)
      log~say('MAIL|'frame['ID']'|'mr~summary(r))
      do f over r['REFS']
        log~say('REFERENCE|'frame['ID']'|'f['VERDICT']'|"'f['PHRASE']'"|owner='f['OWNER']'|role='f['ROLE']'|into='f['DEST']'|candidates='f['CANDIDATES'])
      end
    end
    mind~absorb(readings)
  end
  mind~judge
  do e over mind~ledgerIn
    do note over mind~policiesFor(e)
      log~say('TESTIMONY_POLICY|'e['FROM'] e['KIND'] (e['UNIT'] e['PROV'] e['TLOC'] e['TDEST'])~space'|'note)
    end
  end
  logged = mind~events~items
  do ev over mind~events
    log~say('EVENT|'ev)
  end
  relations = mind~relations
  readMicros = heelTurnMicros(thinkStarted)
  relText = ''
  do p over heelTurnSorted(relations~allIndexes)
    relText = relText p'='relations[p]['REL']'/'format(relations[p]['TRUST'],, 2)
  end
  log~say('RELATIONS|'relText~strip)
  cons = mind~constraints
  cons['RELY'] = mind~relied
  do e over cons['RELY']
    log~say('RELY|'e['FROM'] e['KIND'] e['PROV'] e['VERDICT'])
  end
  do e over mind~cannotTell
    log~say('CANNOT_TELL|'e['FROM'] e['KIND'] e['PROV'] e['TLOC'] e['VERDICT'])
  end
  ctx = mind~context
  kind = view~kind
  -- support asked for by an ally in the final inbox: given silently when
  -- the policy is loyal and the ally has not been caught lying
  if kind == 'MOVEMENT' then if policy~value('loyal', ctx) >= 0.55 then do p over heelTurnSorted(mind~requests~allIndexes)
    if \relations~hasIndex(p) then iterate
    if relations[p]['REL'] \== 'ALLY' then iterate
    do q over mind~requests[p]
      if q['KIND'] \== 'SUPPORT' then iterate
      s = .directory~new
      s['ID'] = p q['TLOC'] q['TDEST']
      s['LOC'] = ''
      s['TTYPE'] = q['TTYPE']
      s['TLOC'] = self~exactLoc(view, q['TTYPE'], q['TLOC'])
      s['TDEST'] = q['TDEST']
      if s['TLOC'] \== '' then cons['SUPPORTS']~append(s)
    end
  end
  planner = .HeelTurnPlanner~new(map, view, a, policy, ctx, relations, cons)
  select
    when kind == 'RETREAT' then plan = planner~retreats
    when kind == 'ADJUSTMENT' then plan = planner~adjustments
    otherwise plan = planner~movement
  end
  out = .array~new
  out~append('Heel Turn SLAM' .HeelTurnEngine~module_version': read' policy~readCount 'of' policy~readCount + policy~notRead~items 'prompt sentences;' a~summary)
  if kind == 'PRESS' then do
    msgs = self~compose(view, map, a, mind, policy, plan, relations, readings)
    do m over msgs
      out~append('SEND TO:' m['NUMBER'])
      out~append('MESSAGE:')
      out~append(m['BODY'])
      out~append('END MESSAGE')
      log~say('SEND|'m['TO']'|'m['NUMBER']'|'m['BODY'])
    end
  end
  else do
    phaseKind = kind
    checked = planner~check(plan['ORDERS'], phaseKind)
    do failure over checked[2]
      log~say('ORDER_CHECK_FAIL|'failure)
    end
    if kind == 'MOVEMENT' then mind~recordGround
    out~append('ORDERS:')
    do line over checked[1]
      out~append(line)
    end
    out~append('END ORDERS')
    log~say('ORDERS|'checked[1]~makeString('L', '; '))
  end
  do k = logged + 1 to mind~events~items
    log~say('EVENT|'mind~events[k])
  end
  memoryText = mind~serialize
  out~append('MEMORY:')
  out~append(memoryText)
  out~append('END MEMORY')
  log~say('MEMORY|chars='memoryText~length)
  return out~makeString('L', '0A'x)
::method exactLoc private
  use strict arg view, utype, loc
  parse var loc b '/' .
  do u over view~units
    if u['TYPE'] == utype then if u['BASE'] == b then return u['LOC']
  end
  return ''
::method compose
  -- What to say, to whom. Every sentence is a chosen act realised by the
  -- writer; whether it is meant is recorded (OUT sincere 1/0) so Heel Turn
  -- keeps its own promises and its own lies straight.
  expose log
  use strict arg view, map, a, mind, policy, plan, relations, readings
  ctx = mind~context
  me = view~me
  talk = policy~value('talk', ctx)
  warmth = policy~value('warmth', ctx)
  brevity = policy~value('brevity', ctx)
  openness = policy~value('openness', ctx)
  promises = policy~value('promises', ctx)
  loyal = policy~value('loyal', ctx)
  retaliate = policy~value('retaliate', ctx)
  writer = .HeelTurnMessageWriter~new(warmth, brevity)
  maxMsgs = min(6, 1 + trunc(talk * 5))
  maxSent = 2 + trunc((1 - brevity) * 4)
  wrote = .directory~new
  do r over readings
    wrote[r['FROM']] = r
  end
  -- order recipients: allies, target, neighbours, then the rest
  order = .array~new
  do p over heelTurnSorted(relations~allIndexes)
    rel = relations[p]['REL']
    rank = 5
    select
      when rel == 'ALLY' then rank = 1
      when rel == 'TARGET' then rank = 2
      when wrote~hasIndex(p) then rank = 3
      when a~isNeighbour(p) then rank = 4
      otherwise nop
    end
    order~append(rank p)
  end
  order = order~sort
  enemy = ''
  worst = 99
  do p over heelTurnSorted(relations~allIndexes)
    if relations[p]['REL'] == 'ALLY' | relations[p]['REL'] == 'TARGET' then iterate
    if \a~isNeighbour(p) then iterate
    if relations[p]['SCORE'] < worst then do
      worst = relations[p]['SCORE']
      enemy = p
    end
  end
  msgs = .array~new
  do entry over order
    if msgs~items >= maxMsgs then leave
    x = entry~word(2)
    num = view~numberFor(x)
    if num = 0 then iterate
    if talk < 0.25 then if \wrote~hasIndex(x) then iterate
    rel = relations[x]['REL']
    lieOK = policy~value('honesty', mind~context(x)) < 0.5
    acts = .array~new
    -- replies first: what they asked, what they did
    if mind~brokeBy~hasIndex(x) then do
      e = mind~brokeBy[x]
      acts~append(heelTurnAct('ACCUSE', x, e['PROV']))
      if retaliate >= 0.6 then acts~append(heelTurnAct('THREAT', x, ''))
    end
    else if mind~keptBy~hasIndex(x) then if warmth >= 0.45 then acts~append(heelTurnAct('THANK', x, ''))
    if mind~threatsBy~hasIndex(x) then if retaliate >= 0.6 then if \mind~brokeBy~hasIndex(x) then acts~append(heelTurnAct('THREAT', x, ''))
    if mind~requests~hasIndex(x) then do q over mind~requests[x]
      if q['KIND'] == 'SUPPORT' then self~answerSupport(acts, x, q, view, map, a, mind, plan, rel, lieOK, loyal)
      if q['KIND'] == 'BOUNCE' then self~answerBounce(acts, x, q, view, map, a, mind, plan, rel, lieOK)
      if q['KIND'] == 'DISLODGE_ME' then self~answerDislodgeMe(acts, x, q, view, map, a, mind, rel)
      if q['KIND'] == 'DISLODGE_THEM' then self~answerDislodgeThem(acts, x, q, view, map, a, mind, policy, rel, lieOK)
      if q['KIND'] == 'NOMOVE' then do
        prov = map~base(q['PROV'])
        if \plan['INTO']~hasIndex(prov) & rel \== 'ENEMY' then do
          acts~append(heelTurnAct('AGREE_DMZ', x, prov))
          mind~promise(x, 'NOMOVE', '', prov, '', '', '', '1')
        end
        else if lieOK then do
          acts~append(heelTurnAct('AGREE_DMZ', x, prov))
          mind~promise(x, 'NOMOVE', '', prov, '', '', '', '0')
        end
        else acts~append(heelTurnAct('REFUSE_DMZ', x, prov))
      end
    end
    -- questions put to me about my own play, answered from the plan under
    -- the same honesty rule as every other promise
    do rd over readings
      if rd['FROM'] \== x then iterate
      do q over rd['ASKS']
        self~answerAsk(acts, x, q, map, a, mind, plan, rel, lieOK, openness, me)
      end
    end
    -- a reference Boston Crab's policy finds ambiguous: ask which unit is meant
    if wrote~hasIndex(x) then do f over wrote[x]['REFS']
      if f['DEST'] == '' then iterate
      if f['VERDICT'] == 'AMBIGUOUS' then if f['OWNER'] == view~me then if \mind~said(x, 'CLARIFY' f['DEST']) then do
        acts~append(heelTurnAct('CLARIFY_MINE', x, f['DEST']))
        mind~markSaid(x, 'CLARIFY' f['DEST'])
      end
      if f['VERDICT'] == 'WRITER AMBIGUOUS' then if f['OWNER'] == x then if \mind~said(x, 'CLARIFY' f['DEST']) then do
        acts~append(heelTurnAct('CLARIFY_YOURS', x, f['DEST']))
        mind~markSaid(x, 'CLARIFY' f['DEST'])
      end
    end
    -- corroboration: a promise from x that Heel Turn cannot tell about
    do e over mind~cannotTell
      if e['FROM'] \== x then iterate
      if e['KIND'] \== 'NOMOVE' then iterate
      if mind~said(x, 'CONFIRM' e['PROV']) then iterate
      acts~append(heelTurnAct('CONFIRM_NOMOVE', x, e['PROV']))
      mind~markSaid(x, 'CONFIRM' e['PROV'])
    end
    -- the opening of a phase: proposals and plans
    if view~round = 1 then do
      if warmth >= 0.6 then if \mind~said(x, 'GREET') then do
        acts~append(heelTurnAct('GREET', x, ''))
        mind~markSaid(x, 'GREET')
      end
      select
        when rel == 'ALLY' then do
          if \mind~said(x, 'ALLY') then do
            act = heelTurnAct('ALLY', x, '')
            if enemy \== x then act['AGAINST'] = enemy
            acts~append(act)
            mind~markSaid(x, 'ALLY')
          end
          self~proposeDislodge(acts, x, view, map, a, mind, plan, relations)
          self~askSupport(acts, x, view, map, a, plan, mind)
          if openness >= 0.5 then self~tellPlans(acts, x, map, a, mind, plan, 1)
          self~offerDmz(acts, x, view, map, a, mind, plan, promises, '1')
        end
        when rel == 'TARGET' then do
          -- the stab: cover it with a lie only where the policy allows one
          if plan['ATTACKS']~hasIndex(x) & lieOK then do prov over plan['ATTACKS'][x]
            if mind~promisedTo(x, prov) \== .nil then iterate
            acts~append(heelTurnAct('NOMOVE', x, prov))
            mind~promise(x, 'NOMOVE', '', prov, '', '', '', '0')
          end
          -- an alliance offered to the power I am stabbing is a lie I tell
          if \mind~said(x, 'ALLY') then do
            acts~append(heelTurnAct('ALLY', x, ''))
            mind~markSaid(x, 'ALLY')
            if plan['ATTACKS']~hasIndex(x) then mind~promise(x, 'ALLY', '', '', '', '', '', '0')
          end
        end
        when rel == 'ENEMY' then do
          if warmth < 0.4 then if \mind~said(x, 'THREAT') then do
            acts~append(heelTurnAct('THREAT', x, ''))
            mind~markSaid(x, 'THREAT')
          end
        end
        otherwise do
          if plan['ATTACKS']~hasIndex(x) then do
            if lieOK then do prov over plan['ATTACKS'][x]
              if mind~promisedTo(x, prov) \== .nil then iterate
              acts~append(heelTurnAct('NOMOVE', x, prov))
              mind~promise(x, 'NOMOVE', '', prov, '', '', '', '0')
            end
          end
          else do
            -- trust that cannot be told: a bounce keeps the province empty
            -- whatever they do; a DMZ only if they keep it
            if a~isNeighbour(x) then do
              if mind~trust[x] < 0.5 | policy~value('suspicion', ctx) >= 0.6 then self~offerBounce(acts, x, view, map, a, mind, plan, promises)
              else self~offerDmz(acts, x, view, map, a, mind, plan, promises, '1')
            end
            if talk >= 0.7 then self~askPlans(acts, x, map, a, mind)
          end
        end
      end
    end
    if acts~items = 0 then iterate
    onlyGreeting = .true
    do act over acts
      if act['ACT'] \== 'GREET' then onlyGreeting = .false
    end
    if onlyGreeting then iterate
    sentences = .array~new
    do act over acts
      if sentences~items >= maxSent then leave
      line = writer~say(act)
      if line \== '' then sentences~append(line)
    end
    if sentences~items = 0 then iterate
    m = .directory~new
    m['TO'] = x
    m['NUMBER'] = num
    m['BODY'] = sentences~makeString('L', ' ')
    msgs~append(m)
  end
  return msgs
::method answerSupport private
  use strict arg acts, x, q, view, map, a, mind, plan, rel, lieOK, loyal
  tloc = self~exactLoc(view, q['TTYPE'], q['TLOC'])
  unit = q['TTYPE'] q['TLOC']
  if tloc == '' | rel == 'ENEMY' then do
    acts~append(heelTurnAct('REFUSE_SUPPORT', x, '', unit))
    return
  end
  aim = tloc
  if q['TDEST'] \== '' then aim = q['TDEST']
  helper = ''
  do u over a~myUnits
    if u['BASE'] == map~base(aim) then iterate
    if \map~reaches(u['TYPE'], u['LOC'], aim) then iterate
    moving = .false
    do line over plan['ORDERS']
      if line~word(1) line~word(2) == u['TYPE'] u['LOC'] then if line~word(3) \== 'H' then moving = .true
    end
    if moving then iterate
    helper = u['TYPE'] u['LOC']
    leave
  end
  mineAim = a~owner(map~base(aim)) == view~me
  if helper \== '' & \mineAim & loyal >= 0.4 & rel \== 'TARGET' then do
    act = heelTurnAct('GIVE_SUPPORT', x, q['TDEST'], q['TTYPE'] tloc)
    if q['TDEST'] == '' then act['ACT'] = 'GIVE_SUPPORT_HOLD'
    acts~append(act)
    mind~promise(x, 'SUPPORT', helper, '', q['TTYPE'], tloc, q['TDEST'], '1')
    return
  end
  if lieOK then do
    act = heelTurnAct('GIVE_SUPPORT', x, q['TDEST'], q['TTYPE'] tloc)
    if q['TDEST'] == '' then act['ACT'] = 'GIVE_SUPPORT_HOLD'
    acts~append(act)
    mind~promise(x, 'SUPPORT', '', '', q['TTYPE'], tloc, q['TDEST'], '0')
    return
  end
  acts~append(heelTurnAct('REFUSE_SUPPORT', x, '', q['TTYPE'] tloc))
::method answerAsk private
  -- MOVE P: going there -> told to a non-enemy when open, a lie or a decline
  -- when it is an attack on the asker; not going -> "I will not move into P"
  -- (a promise that binds my orders). ATTACK me: not planned -> "I will not
  -- attack you" (binds); planned -> a lie where allowed, else a decline.
  -- PLANS: told when open to a non-enemy, else a decline. Third powers: decline.
  use strict arg acts, x, q, map, a, mind, plan, rel, lieOK, openness, me
  -- a province of mine (I own it or my unit is there) asks what my unit
  -- there will do: never answered with a promise to stay out of my own ground
  if q['PROV'] \== '' then do
    p = map~base(q['PROV'])
    if a~owner(p) == me | self~myUnitAt(a, p) \== .nil then do
      self~answerOwn(acts, x, p, map, a, mind, plan, rel, openness)
      return
    end
  end
  select
    when q['KIND'] == 'MOVE' then self~answerMove(acts, x, map~base(q['PROV']), map, mind, plan, rel, lieOK, openness)
    when q['KIND'] == 'ATTACK' then do
      if mind~said(x, 'ANSWER_ATTACK') then return
      mind~markSaid(x, 'ANSWER_ATTACK')
      if q['POWER'] \== x then do
        acts~append(heelTurnAct('DECLINE', x, ''))
        return
      end
      choice = heelTurnAnswerChoice('ATTACK', plan['ATTACKS']~hasIndex(x), .true, lieOK, openness >= 0.5 & rel \== 'ENEMY')
      if choice == 'DECLINE' then acts~append(heelTurnAct('DECLINE', x, ''))
      else do
        acts~append(heelTurnAct('NOATTACK', x, ''))
        mind~promise(x, 'NOATTACK', '', '', '', '', '', choice~word(2))
      end
    end
    when q['KIND'] == 'PLANS' then do
      if q['PROV'] \== '' then do
        self~answerMove(acts, x, map~base(q['PROV']), map, mind, plan, rel, lieOK, openness)
        return
      end
      if mind~said(x, 'ANSWER_PLANS') then return
      mind~markSaid(x, 'ANSWER_PLANS')
      before = acts~items
      if openness >= 0.5 & rel \== 'ENEMY' then self~tellPlans(acts, x, map, a, mind, plan, 1)
      if acts~items = before then acts~append(heelTurnAct('DECLINE', x, ''))
    end
    otherwise nop
  end
::method myUnitAt private
  use strict arg a, p
  do u over a~myUnits
    if u['BASE'] == p then return u
  end
  return .nil
::method answerOwn private
  use strict arg acts, x, p, map, a, mind, plan, rel, openness
  if mind~said(x, 'ANSWER' p) then return
  mind~markSaid(x, 'ANSWER' p)
  u = self~myUnitAt(a, p)
  if u == .nil | openness < 0.5 | rel == 'ENEMY' then do
    acts~append(heelTurnAct('DECLINE', x, p))
    return
  end
  -- one unit, one story: a move already promised is told again as it was;
  -- a unit in an agreement is not discussed
  told = mind~toldMove(u['TYPE'] u['LOC'])
  if told \== '' then do
    acts~append(heelTurnAct('MOVE', x, told, u['TYPE'] u['LOC']))
    if mind~promisedTo(x, told) == .nil then mind~promise(x, 'MOVE', u['TYPE'] u['LOC'], told, '', '', '', '1')
    return
  end
  if mind~committed~hasIndex(u['LOC']) then do
    acts~append(heelTurnAct('DECLINE', x, p))
    return
  end
  do line over plan['ORDERS']
    if line~word(1) line~word(2) \== u['TYPE'] u['LOC'] then iterate
    o = heelTurnParseOrder(line)
    db = map~base(o['DEST'])
    if o['ACTION'] == 'MOVE' then if \map~reaches(o['TYPE'], o['LOC'], db) then leave
    if o['ACTION'] == 'MOVE' then do
      if plan['ATTACKS']~hasIndex(x) then if plan['ATTACKS'][x]~hasItem(db) then leave
      acts~append(heelTurnAct('MOVE', x, o['DEST'], o['TYPE'] o['LOC']))
      mind~promise(x, 'MOVE', o['TYPE'] o['LOC'], db, '', '', '', '1')
      mind~markSaid(x, 'MOVE' o['LOC'])
      return
    end
    if o['ACTION'] == 'HOLD' then do
      acts~append(heelTurnAct('HOLD', x, '', o['TYPE'] o['LOC']))
      return
    end
    leave
  end
  acts~append(heelTurnAct('DECLINE', x, p))
::method answerMove private
  use strict arg acts, x, p, map, mind, plan, rel, lieOK, openness
  if mind~promisedTo(x, p) \== .nil then return
  if mind~said(x, 'ANSWER' p) then return
  mind~markSaid(x, 'ANSWER' p)
  againstX = .false
  if plan['ATTACKS']~hasIndex(x) then againstX = plan['ATTACKS'][x]~hasItem(p)
  choice = heelTurnAnswerChoice('MOVE', plan['INTO']~hasIndex(p), againstX, lieOK, openness >= 0.5 & rel \== 'ENEMY')
  if choice~word(1) == 'NOMOVE' then do
    acts~append(heelTurnAct('NOMOVE', x, p))
    mind~promise(x, 'NOMOVE', '', p, '', '', '', choice~word(2))
    return
  end
  busy = mind~committed
  if choice == 'TELL' then do line over plan['ORDERS']
    o = heelTurnParseOrder(line)
    if o['ACTION'] \== 'MOVE' then iterate
    if busy~hasIndex(o['LOC']) then iterate
    if \map~reaches(o['TYPE'], o['LOC'], map~base(o['DEST'])) then iterate
    if map~base(o['DEST']) \== p then iterate
    acts~append(heelTurnAct('MOVE', x, o['DEST'], o['TYPE'] o['LOC']))
    mind~promise(x, 'MOVE', o['TYPE'] o['LOC'], p, '', '', '', '1')
    mind~markSaid(x, 'MOVE' o['LOC'])
    return
  end
  acts~append(heelTurnAct('DECLINE', x, p))
::method askSupport private
  -- Ask an ally to support one contested move it can reach.
  use strict arg acts, x, view, map, a, plan, mind = .nil
  busy = .directory~new
  if mind \== .nil then busy = mind~committed
  do line over plan['ORDERS']
    o = heelTurnParseOrder(line)
    if o['ACTION'] \== 'MOVE' then iterate
    if busy~hasIndex(o['LOC']) then iterate
    db = map~base(o['DEST'])
    if a~threats(db)~items = 0 then if \a~unitAt~hasIndex(db) then iterate
    do u over view~units
      if u['OWNER'] \== x then iterate
      if \map~reaches(u['TYPE'], u['LOC'], db) then iterate
      acts~append(heelTurnAct('ASK_SUPPORT', x, o['DEST'], o['TYPE'] o['LOC']))
      return
    end
  end
::method tellPlans private
  -- True plans, told to an ally: moves that do not touch the ally.
  use strict arg acts, x, map, a, mind, plan, limit
  told = 0
  busy = mind~committed
  do line over plan['ORDERS']
    if told >= limit then leave
    o = heelTurnParseOrder(line)
    if o['ACTION'] \== 'MOVE' then iterate
    if busy~hasIndex(o['LOC']) then iterate
    db = map~base(o['DEST'])
    -- a convoyed move rests on a fleet's order: never told as a promise
    if \map~reaches(o['TYPE'], o['LOC'], db) then iterate
    if plan['ATTACKS']~hasIndex(x) then if plan['ATTACKS'][x]~hasItem(db) then iterate
    if mind~said(x, 'MOVE' o['LOC']) then iterate
    acts~append(heelTurnAct('MOVE', x, o['DEST'], o['TYPE'] o['LOC']))
    mind~promise(x, 'MOVE', o['TYPE'] o['LOC'], db, '', '', '', '1')
    mind~markSaid(x, 'MOVE' o['LOC'])
    told += 1
  end
::method offerBounce private
  -- a border province both can reach, not a centre, not in my plan: my unit
  -- and theirs both move in, unsupported, and it stays empty
  use strict arg acts, x, view, map, a, mind, plan, promises
  if promises < 0.45 then return
  if mind~said(x, 'DMZ') then return
  busy = mind~committed
  do u over a~myUnits
    if busy~hasIndex(u['LOC']) then iterate
    do d over map~dests(u['TYPE'], u['LOC'])
      prov = map~base(d)
      if plan['INTO']~hasIndex(prov) then iterate
      if a~unitAt~hasIndex(prov) then iterate
      if map~isCentre(prov) then iterate
      if mind~promisedTo(x, prov) \== .nil then iterate
      if mind~agreedProvinces~hasIndex(prov) then iterate
      if mind~bounceUnit(prov) \== '' then iterate
      -- a bounce is a move in: never where I promised anyone to stay out
      if mind~noMoveMeant(prov) then iterate
      theirs = ''
      do t over view~units
        if t['OWNER'] == x then if map~reaches(t['TYPE'], t['LOC'], prov) then theirs = t['TYPE'] t['LOC']
      end
      if theirs == '' then iterate
      act = heelTurnAct('PROPOSE_BOUNCE', x, prov, u['TYPE'] u['LOC'])
      act['THEIRS'] = theirs
      acts~append(act)
      mind~promise(x, 'BOUNCE', u['TYPE'] u['LOC'], prov, '', '', '', '1')
      mind~markSaid(x, 'DMZ')
      return
    end
  end
::method answerBounce private
  -- agree when one of my units can move into P without breaking another
  -- promise; a liar may agree and support itself in to take P
  use strict arg acts, x, q, view, map, a, mind, plan, rel, lieOK
  p = map~base(q['PROV'])
  if mind~said(x, 'BOUNCE' p) then return
  mind~markSaid(x, 'BOUNCE' p)
  -- one unit, one promise: the unit already in a bounce in P says it again;
  -- otherwise a unit no other agreement or told move has spoken for
  unit = mind~bounceUnit(p)
  if unit \== '' then do
    acts~append(heelTurnAct('ACCEPT_BOUNCE', x, p, unit))
    if mind~promisedTo(x, p) == .nil then mind~promise(x, 'BOUNCE', unit, p, '', '', '', '1')
    return
  end
  busy = mind~committed
  do u over a~myUnits
    if busy~hasIndex(u['LOC']) then iterate
    if q['TLOC'] \== '' then if u['TYPE'] u['LOC'] \== q['TLOC'] then iterate
    if \map~reaches(u['TYPE'], u['LOC'], p) then iterate
    unit = u['TYPE'] u['LOC']
    leave
  end
  nomove = mind~noMoveMeant(p)
  if unit == '' | nomove | rel == 'ENEMY' then do
    acts~append(heelTurnAct('REFUSE_BOUNCE', x, p))
    return
  end
  acts~append(heelTurnAct('ACCEPT_BOUNCE', x, p, unit))
  sincere = '1'
  if lieOK & map~isCentre(p) then sincere = '0'
  mind~promise(x, 'BOUNCE', unit, p, '', '', '', sincere)
::method retreatSafe private
  -- a retreat to Q will be open after the movement: Q empty now, no hostile
  -- unit able to reach it, and none of the attacker's units but the attacker
  -- itself able to reach it (or the dislodge is a trap)
  use strict arg view, map, a, q, attackerOwner, attacker, me
  if a~unitAt~hasIndex(q) then return .false
  do u over view~units
    if u['OWNER'] == me then iterate
    if u['TYPE'] u['LOC'] == attacker then iterate
    if map~reaches(u['TYPE'], u['LOC'], q) then return .false
  end
  return .true
::method answerDislodgeMe private
  -- they dislodge my unit in P and it retreats to Q: an ally only, never a
  -- centre of mine, and only if Q will be open (the trap is Q taken)
  use strict arg acts, x, q, view, map, a, mind, rel
  p = map~base(q['PROV'])
  if mind~said(x, 'DISLODGE' p) then return
  mind~markSaid(x, 'DISLODGE' p)
  me = view~me
  victim = q['TTYPE'] q['TLOC']
  mineThere = .false
  busy = mind~committed
  do u over a~myUnits
    if u['TYPE'] u['LOC'] == victim then if \busy~hasIndex(u['LOC']) then mineThere = .true
  end
  dest = map~base(q['TDEST'])
  ok = rel == 'ALLY' & mineThere & a~owner(p) \== me & dest \== '' & map~reaches(q['TTYPE'], q['TLOC'], dest)
  if ok then ok = self~retreatSafe(view, map, a, dest, x, q['UNIT'], me)
  if \ok then do
    acts~append(heelTurnAct('REFUSE_DISLODGE', x, p))
    return
  end
  act = heelTurnAct('ACCEPT_DISLODGE', x, p, q['UNIT'])
  act['SUPPORTER'] = q['SUPPORTER']
  if act['SUPPORTER'] == '' then act['SUPPORTER'] = 'their supporter'
  act['VICTIM'] = victim
  act['VICTIM_MINE'] = 1
  act['DEST'] = q['TDEST']
  acts~append(act)
  mind~promise(x, 'DISLODGE_ME', q['UNIT'], p, q['TTYPE'], q['TLOC'], q['TDEST'], '1')
::method answerDislodgeThem private
  -- an ally asks me to dislodge its unit in P so it retreats to Q: agree when
  -- I have an attacker and a supporter for P. A liar who will stab may agree
  -- and spring the trap: the dislodge goes ahead and a third unit takes Q.
  use strict arg acts, x, q, view, map, a, mind, policy, rel, lieOK
  p = map~base(q['PROV'])
  if mind~said(x, 'DISLODGE' p) then return
  mind~markSaid(x, 'DISLODGE' p)
  me = view~me
  attacker = .nil
  supporter = .nil
  busy = mind~committed
  do u over a~myUnits
    if busy~hasIndex(u['LOC']) then iterate
    if \map~reaches(u['TYPE'], u['LOC'], p) then iterate
    if q['UNIT'] \== '' then if u['TYPE'] u['LOC'] == q['UNIT'] then do
      attacker = u
      iterate
    end
    if attacker == .nil & q['UNIT'] == '' then do
      attacker = u
      iterate
    end
    if supporter == .nil then supporter = u
  end
  -- an ally, or the ally the policy has chosen to stab
  if attacker == .nil | supporter == .nil | wordpos(rel, 'ALLY TARGET') = 0 then do
    acts~append(heelTurnAct('REFUSE_DISLODGE', x, p))
    return
  end
  dest = map~base(q['TDEST'])
  trapper = .nil
  if lieOK & policy~value('stab', mind~context(x)) >= 0.5 then do u over a~myUnits
    if u == attacker | u == supporter then iterate
    if map~reaches(u['TYPE'], u['LOC'], dest) then do
      trapper = u
      leave
    end
  end
  act = heelTurnAct('ACCEPT_DISLODGE', x, p, attacker['TYPE'] attacker['LOC'])
  act['SUPPORTER'] = supporter['TYPE'] supporter['LOC']
  act['VICTIM'] = q['TTYPE'] q['TLOC']
  act['VICTIM_MINE'] = 0
  act['DEST'] = q['TDEST']
  acts~append(act)
  mind~promise(x, 'DISLODGE_THEM', attacker['TYPE'] attacker['LOC'], p, q['TTYPE'], q['TLOC'], q['TDEST'], '1')
  -- the supporter named is the one that supports
  mind~promise(x, 'SUPPORT', supporter['TYPE'] supporter['LOC'], '', attacker['TYPE'], attacker['LOC'], p, '1')
  if trapper \== .nil then do
    mind~promise(x, 'TRAP', trapper['TYPE'] trapper['LOC'], dest, '', '', '', '1')
    mind~promise(x, 'KEEPCLEAR', '', dest, '', '', '', '0')
  end
::method proposeDislodge private
  -- as the attacker: an ally's unit stands in a province my plan wants and
  -- is not a supply centre; I have an attacker and a supporter for it; its
  -- retreat Q is open and I have no unit but the attacker able to reach Q
  -- (my word that the dislodge is no trap)
  use strict arg acts, x, view, map, a, mind, plan, relations
  if mind~said(x, 'DISLODGE') then return
  me = view~me
  targets = .array~new
  do c over heelTurnSorted(view~centres~allIndexes)
    w = view~centres[c]
    if w == me | w == x then iterate
    if relations~hasIndex(w) then if relations[w]['REL'] == 'ALLY' then iterate
    targets~append(c)
  end
  if targets~items = 0 then return
  dist = map~distances(targets)
  do e over view~units
    if e['OWNER'] \== x then iterate
    p = e['BASE']
    if map~isCentre(p) then iterate
    -- the attacker: a unit for which p lies on the way to a centre I am
    -- after (p nearer the nearest target than the unit is); the supporter:
    -- any other unit that reaches p
    near = .array~new
    busy = mind~committed
    do u over a~myUnits
      if busy~hasIndex(u['LOC']) then iterate
      if map~reaches(u['TYPE'], u['LOC'], p) then near~append(u)
    end
    if near~items < 2 then iterate
    attacker = .nil
    do u over near
      if \dist~hasIndex(p) | \dist~hasIndex(u['BASE']) then iterate
      if dist[p] < dist[u['BASE']] then do
        attacker = u
        leave
      end
    end
    if attacker == .nil then iterate
    supporter = .nil
    do u over near
      if u \== attacker then if supporter == .nil then supporter = u
    end
    best = ''
    do d over map~dests(e['TYPE'], e['LOC'])
      qd = map~base(d)
      if qd == attacker['BASE'] then iterate
      if \self~retreatSafe(view, map, a, qd, me, attacker['TYPE'] attacker['LOC'], x) then iterate
      mineNear = .false
      do u over a~myUnits
        if u == attacker then iterate
        if map~reaches(u['TYPE'], u['LOC'], qd) then mineNear = .true
      end
      if mineNear then iterate
      best = d
      leave
    end
    if best == '' then iterate
    act = heelTurnAct('PROPOSE_DISLODGE', x, p, attacker['TYPE'] attacker['LOC'])
    act['SUPPORTER'] = supporter['TYPE'] supporter['LOC']
    act['VICTIM'] = e['TYPE'] e['LOC']
    act['VICTIM_MINE'] = 0
    act['DEST'] = best
    acts~append(act)
    mind~promise(x, 'DISLODGE_THEM', attacker['TYPE'] attacker['LOC'], p, e['TYPE'], e['LOC'], best, '1')
    mind~promise(x, 'SUPPORT', supporter['TYPE'] supporter['LOC'], '', attacker['TYPE'], attacker['LOC'], p, '1')
    mind~markSaid(x, 'DISLODGE')
    return
  end
::method offerDmz private
  -- One border province both sides can reach, that the plan does not enter.
  expose log
  use strict arg acts, x, view, map, a, mind, plan, promises, sincere
  if promises < 0.45 then return
  if mind~said(x, 'DMZ') then return
  mineReach = .directory~new
  do u over a~myUnits
    do d over map~dests(u['TYPE'], u['LOC'])
      mineReach[map~base(d)] = 1
    end
  end
  do prov over heelTurnSorted(mineReach~allIndexes)
    if plan['INTO']~hasIndex(prov) then iterate
    if a~unitAt~hasIndex(prov) then iterate
    if a~owner(prov) == view~me then iterate
    -- never offer away a supply centre (a neutral one is a centre to take)
    if map~isCentre(prov) then iterate
    -- already promised to this power this phase (an agreed DMZ): no second offer
    if mind~promisedTo(x, prov) \== .nil then iterate
    if mind~agreedProvinces~hasIndex(prov) then iterate
    theirs = .false
    do u over view~units
      if u['OWNER'] == x then if map~reaches(u['TYPE'], u['LOC'], prov) then theirs = .true
    end
    if \theirs then iterate
    acts~append(heelTurnAct('DMZ', x, prov))
    mind~promise(x, 'NOMOVE', '', prov, '', '', '', sincere)
    mind~markSaid(x, 'DMZ')
    return
  end
::method askPlans private
  use strict arg acts, x, map, a, mind
  if mind~said(x, 'ASK') then return
  do g over a~groundOf(x)
    if \map~isCentre(g) then iterate
    acts~append(heelTurnAct('ASK_PLANS', x, g))
    mind~markSaid(x, 'ASK')
    return
  end
::method module_version class
  return '0.2'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnAct public
  use strict arg act, to, prov, unit = ''
  d = .directory~new
  d['ACT'] = act
  d['TO'] = to
  d['PROV'] = prov
  d['UNIT'] = unit
  d['AGAINST'] = ''
  d['POWER'] = ''
  return d

::routine heelTurnMicros public
  -- Whole microseconds since a .DateTime.
  use strict arg since
  span = .DateTime~new - since
  return span~totalMicroseconds~format(, 0)~strip

::routine heelTurnAnswerChoice public
  -- The answer to "will you move into P?" (MOVE) or "will you attack me?"
  -- (ATTACK). going: the plan does it. against: it is against the asker.
  -- open: openness >= 0.5 and the asker is not an enemy. Returns TELL,
  -- NOMOVE 1 / NOATTACK 1 (a promise I mean), NOMOVE 0 / NOATTACK 0 (a lie,
  -- only where the honesty setting allows one), or DECLINE.
  use strict arg kind, going, against, lieOK, open
  promise = 'NOMOVE'
  if kind == 'ATTACK' then promise = 'NOATTACK'
  if \going then return promise '1'
  if kind == 'MOVE' & \against then do
    if open then return 'TELL'
    return 'DECLINE'
  end
  if lieOK then return promise '0'
  return 'DECLINE'
