/* order_check.rex - read an order from where its recipient stands.             */
/* The situation is narration: what is where, and what each person cannot see */
/* ("Lucan could not see the British guns"). Everything else in it counts as    */
/* identifiable to everyone (open world). An                                    */
/* "# Order - A to B" or "# Message - A to B" section is kept as an order and   */
/* never read into the world. Each definite reference in it ("the guns") is     */
/* matched by concept, never by word, against what the writer can see and what  */
/* the recipient can see:                                                       */
/*   CLEAR             one thing for each, and the same thing                   */
/*   AMBIGUOUS         the recipient can see more than one thing it could mean  */
/*   NOT VISIBLE       the recipient can see nothing it could mean              */
/*   WRITER AMBIGUOUS  it fits more than one thing the writer can see, so the   */
/*                     words alone do not say which he means                    */
/*   NO REFERENT       neither can see anything it could mean ("the front")     */
/*   MEANS DIFFERENT THINGS  each sees exactly one, and they are not the same    */
/* An order's "the cavalry" defaults to what the recipient commands, when he    */
/* commands one of the candidates (stated in the situation).                     */
/* Also flagged: "at" + an event ("we are at takeoff": a place, or doing it?),  */
/* and a bare acknowledgement ("OK") of a message that still has an open        */
/* question, because it does not say which reading was taken.                   */
/* Parts the reader cannot read are listed as NOT CHECKED, never passed.        */
/* Usage: rexx order_check.rex dir                                              */
/* Architecture: Tom Dyer. This file: Claude (Opus 5.5).                         */
parse arg dir .
if dir == '' then dir = '.'
rd = .Reader~new(dir)
rd~readFile(dir'/story.txt')
cs = rd~cs
lex = rd~lex
ents = rd~ents
rz = .Realiser~new(rd)
seeC = classOf('*see', 'seeclass')
cmdC = classOf('*command', 'commandclass')
eventC = classOf('*event', 'eventclass')

/* who can see what; who commands what; what kinds things are said to be */
view = .StringTable~new
hidden = .StringTable~new
cmd = .StringTable~new
kinds = .StringTable~new
do pid over rd~order
  p = rd~props[pid]
  if p['ACT'] \== 'narrate' then iterate
  r = p['ROLES']
  if p['EVENT'] \== '' then do
    a = ent(r['agent'])
    t = ent(r['patient'])
    if a \== '' then if t \== '' then do
      if cs~isa(p['EVENT'], seeC) then do
        if p['POL'] == '+' then call addTo view, a, t
        else call addTo hidden, a, t
      end
      if cmdC \== '' then if cs~isa(p['EVENT'], cmdC) then if p['POL'] == '+' then call addTo cmd, a, t
    end
  end
  h = ent(r['holder'])
  k = r['kind']
  if h \== '' then if k~isA(.String) then call addTo kinds, h, k
end

/* a map: Top Rope Slam's sight lines ("sight lucan reverse-slope-mid
   SOMETIMES 110 225"), bound to the situation by bind.words ("bind
   reverse-slope-mid the British guns"). CANNOT rules a thing out for that
   person; SOMETIMES leaves it in, with the count said beside it. */
mapNote = .StringTable~new        /* "who/what" -> "110 of 225" */
mapUsed = 0
mapSource = 'sight lines (sight.words names no source)'
if SysFileExists(dir'/sight.words') & SysFileExists(dir'/bind.words') then do
  bind = .StringTable~new
  bs = .Stream~new(dir'/bind.words')~~open('read')
  do while bs~lines > 0
    ln = bs~linein~strip
    if ln = '' | ln~left(2) = '--' then iterate
    parse var ln 'bind' place phrase
    e = bindTo(phrase~strip)
    if e == '' then do
      say 'bind.words: no one thing in the situation is "'phrase~strip'"'
      exit 2
    end
    bind[place] = e
  end
  bs~close
  ss = .Stream~new(dir'/sight.words')~~open('read')
  do while ss~lines > 0
    ln = ss~linein~strip
    /* "source SLAM 450 line of sight ...": what made these sight lines */
    if ln~word(1) == 'source' then mapSource = ln~subword(2)
    if ln~word(1) \== 'sight' then iterate
    parse var ln 'sight' pa pb verdict seen tried .
    if \bind~hasIndex(pa) | \bind~hasIndex(pb) then iterate
    a = bind[pa]; b = bind[pb]
    mapUsed = mapUsed + 1
    select
      when verdict = 'CANNOT' then do
        call addTo hidden, a, b
        mapNote[a || '/' || b] = 'map: seen from 0 of' tried 'positions'
      end
      when verdict = 'SOMETIMES' then mapNote[a || '/' || b] = 'map: seen from' seen 'of' tried 'positions'
      otherwise nop
    end
  end
  ss~close
end

o = .Stream~new(dir'/out/orders.txt')~~open('write replace')
/* the same report for machines: one fact a line, fields split by | */
mo = .Stream~new(dir'/out/orders.words')~~open('write replace')
mo~lineout('-- orders.words: Boston Crab order report for programs. Fields split by |.')
mo~lineout('-- order|n|from|to|words    part|n|i|verb|action|how|words    ref|n|i|verdict|words|writer|reader    end|n|verdict')
mo~lineout('-- verb, action and how are concept names (language neutral), - for none; action is the verb, or the act after a general verb')
mo~lineout('-- ("conduct a search": search); writer and reader list what each can identify, split by ;')
mo~lineout('-- how holds "not" when the part says not to do it ("не знижуйтесь", "do not descend"),')
mo~lineout('-- and "if" when it waits on a condition said in its words ("якщо ціль знайдено", "if the target is found")')
mo~lineout('-- tone|n|frustration|count when the sender swears (twice or more: extreme frustration); it is not an order')
mo~lineout('-- say|n|i|uk|writer|reader follows a ref of a Ukrainian order: the same things said in Ukrainian, nominative')
mo~lineout('-- ("північно-східний пілон"; names as written), - where a thing has no Ukrainian words yet')
mo~lineout('-- a grid reference has writer and reader "grid E <east> N <north>"; fail|n|reason when Boston Crab failed on an order')
lightC = ''
if lex~entries~hasIndex('*light') then do lc over lex~entries['*light']
  lightC = lightC lc['CONCEPT']
end
on = 0
/* Ukrainian words for saying things back: concept -> nominative noun (by
   number) and its gender; adjective concept -> nominative by gender */
ukN = .StringTable~new
ukG = .StringTable~new
ukA = .StringTable~new
do ukL over lex~entries~allIndexes
  do ukX over lex~entries[ukL]
    ukF = ukX['FEATS']
    if \ukF~hasIndex('lang') then iterate
    if \ukF~hasIndex('case') then iterate
    if ukF['case'] \== 'nom' then iterate
    if words(ukL) > 1 then iterate
    if ukX['POS'] == 'noun' then do
      if \ukN~hasIndex(ukX['CONCEPT']'/'ukF['num']) then ukN[ukX['CONCEPT']'/'ukF['num']] = ukL
      if ukF~hasIndex('gen') then if \ukG~hasIndex(ukX['CONCEPT']) then ukG[ukX['CONCEPT']] = ukF['gen']
    end
    if ukX['POS'] == 'adj' then do
      ukK = 'p'
      if ukF['num'] == 'sg' then ukK = ukF['gen']
      if \ukA~hasIndex(ukX['CONCEPT']'/'ukK) then ukA[ukX['CONCEPT']'/'ukK] = ukL
    end
  end
end
call out 'Orders and messages:' rd~orders~items
/* what the situation says that the reader could not read: checks against
   it may be wrong, so it is said first ("Scarlet was near ..." unread) */
if rd~unread~items > 0 then do
  call out 'Situation not read:' rd~unread~items 'sentence(s); a reference to what they describe may be judged wrongly'
  do x over rd~unread
    call out '  UNREAD  '||x
  end
end
if mapUsed > 0 then call out 'Map:' mapSource',' mapUsed 'sight lines, bound to the situation'
oneOfGroup = 0
open = .StringTable~new           /* "sender/addressee" -> the open questions in his last message to him */
openSec = .StringTable~new        /* "sender/addressee" -> the section that message is in */
/* one order that fails inside Boston Crab is said NOT CHECKED, and the
   others are still checked (a whole batch was once lost to one order) */
oStart = 1
orderLoop:
signal on syntax name orderCrash
do oi = oStart to rd~orders~items
  od = rd~orders[oi]
  on = oi
  headerDone = 0
  mrSay = .array~new
  toks = od['TOKS']
  from = od['FROM']
  to = od['TO']
  text = rd~join(toks, 1, toks~items)
  call out ''
  call out nameOf(from) '->' nameOf(to)':' text
  headerDone = 1
  flags = 0
  unchecked = 0
  mrRefs = .array~new
  /* the parts of an order: "fly to the station and land near the pylon",
     "виконайте обліт ... та огляньте ..." */
  pStart = .array~of(1)
  /* in Ukrainian a comma joins orders too: "працюйте ..., стежте ..." */
  pJoin = 'and та і й'
  if isCyr(text) then pJoin = pJoin ','
  do k = 3 to toks~items - 1
    if wordpos(toks[k], pJoin) = 0 then iterate
    pc = lex~find(toks, k + 1, 'verb')
    if pc == .nil then iterate
    /* in Ukrainian only a command starts a part: "починаючи з" (starting
       from) and "якщо ціль знайдено, підтверджено ..." (if the target is
       found, confirmed ...) go on with the same order */
    if pc['E']['FEATS']~hasIndex('lang') then do
      if pc['E']['FEATS']['form'] \== 'imp' then iterate
      /* "якщо ціль знайдено, ... повертайтеся": words with no command of
         their own are the condition of the command after them */
      pHasCmd = 0
      do pj = pStart[pStart~items] to k
        pv = lex~find(toks, pj, 'verb')
        if pv \== .nil then if pv['E']['FEATS']['form'] == 'imp' then pHasCmd = 1
      end
      if \pHasCmd then iterate
    end
    pStart~append(k + 1)
  end
  pVerb = .array~new
  /* a bare acknowledgement */
  ackOnly = 1
  /* "Bravo, завдання прийняв": the call sign, then the acknowledgement */
  k0 = 1
  if toks~items > 2 then if toks[2] == ',' then if rd~isName(toks[1]) then k0 = 3
  do k = k0 to toks~items
    if verify(toks[k], '.,!?') = 0 then iterate
    c = lex~find(toks, k, 'formula')
    if c == .nil then ackOnly = 0
    else if c['E']['FEATS']['ack'] \== 'yes' then ackOnly = 0
  end
  if ackOnly then do
    /* what is still open in what was sent to this sender, or to all */
    oq = ''
    if open~hasIndex(to'/'from) then oq = open[to'/'from]
    if open~hasIndex(to'/') then oq = oq open[to'/']
    if oq~strip \== '' then do
      call out '  ACK DOES NOT RESOLVE  "'text'" answers a message with an open question ('oq~strip'); it does not say which reading was taken'
      flags = flags + 1
    end
    if oq~strip \== '' then call emitRef 1, 'ACK DOES NOT RESOLVE  ', text, '', ''
    pVerb[1] = 'ACK'
    call finish
    open[from'/'to] = ''
    iterate
  end
  qs = ''
  /* a Ukrainian order: the same concepts, read by ukCheck */
  if isCyr(text) then do
    call ukCheck toks, from, to
    call keepOpen
    call finish
    iterate
  end
  k = 1
  do while k <= toks~items
    c = lex~find(toks, k, 'det')
    isDef = 0
    if c \== .nil then if c['E']['FEATS']['kind'] == 'def' then isDef = 1
    /* "Walsh Bay wharves" with no article is read as "the Walsh Bay wharves" */
    if \isDef then if rd~nameRun(toks, k) \== .nil then do
      np0 = rd~parseNP(toks, k)
      if np0 \== .nil then if np0['KIND'] == 'def' then isDef = 1
    end
    if isDef then do
      np = rd~parseNP(toks, k)
      if np \== .nil then if np['KIND'] == 'def' then do
        /* "the wharf near the station": a place phrase after it says which */
        np['WHERE'] = ''
        nx = np['NEXT']
        if lex~find(toks, nx, 'prep') \== .nil then do
          pp = rd~parsePP(toks, nx)
          if pp \== .nil then if wordpos(pp['ROLE'], 'at to') > 0 then do
            w_ = refEnt(pp['NP'])
            if w_ \== '' then do
              np['WHERE'] = w_
              np['WHERETEXT'] = rd~join(toks, nx, pp['NEXT'] - 1)
              np['NEXT'] = pp['NEXT']
            end
          end
        end
        /* "the west part of the field": check the field, said next */
        if isPartNoun(np['CORE']['CONCEPT']) then if np['NEXT'] <= toks~items then if wordpos(toks[np['NEXT']], 'of between around near beside behind') > 0 then do
          k = np['NEXT']
          iterate
        end
        res = checkRef(np, from, to)
        call emitRef k, res, rd~join(toks, k, np['NEXT'] - 1), w, r
        call out '  'res
        if res~word(1) \== 'CLEAR' then do
          flags = flags + 1
          qs = qs '"'rd~join(toks, k, np['NEXT'] - 1)'"'
        end
        k = np['NEXT']
        iterate
      end
    end
    /* a grid reference: "E -423 N -402" is a place, and needs no situation */
    ge = gridAt(toks, k)
    if ge > 0 then do
      call gridRef k, ge
      k = ge
      iterate
    end
    /* "return to base": a bare noun after a place word is a known place,
       as "the base" is */
    if k > 1 then if wordpos(toks[k - 1], 'to at from near into onto toward towards between around') > 0 then if lex~find(toks, k, 'det') == .nil then if lex~find(toks, k, 'noun') \== .nil then if \rd~isName(toks[k]) then do
      bc = rd~parseCore(toks, k)
      if bc \== .nil then if \inClass(bc['CONCEPT'], '*abstract') then if \isPartNoun(bc['CONCEPT']) then do
        np = .Directory~new
        np['CORE'] = bc
        np['WHERE'] = ''
        res = checkRef(np, from, to)
        call emitRef k, res, rd~join(toks, k, bc['NEXT'] - 1), w, r
        call out '  'res
        if res~word(1) \== 'CLEAR' then do
          flags = flags + 1
          qs = qs rd~join(toks, k, bc['NEXT'] - 1)
        end
        k = bc['NEXT']
        iterate
      end
    end
    /* a named place: can the recipient see it? */
    if rd~isName(toks[k]) | (rd~nameRun(toks, k) \== .nil) then do
      np = rd~parseNP(toks, k)
      if np \== .nil then if np['KIND'] == 'name' then do
        e = nameEnt(np['LABEL'])
        if e == '' then e = nameEnt(rd~join(toks, k, np['NEXT'] - 1))
        /* a name the situation does not have: nobody can say where it is */
        if e == '' then do
          call out '  UNKNOWN NAME  "'rd~join(toks, k, np['NEXT'] - 1)'": the situation has no place or person of that name'nameNear(rd~join(toks, k, np['NEXT'] - 1))
          call emitRef k, 'UNKNOWN NAME  ', rd~join(toks, k, np['NEXT'] - 1), '', ''
          flags = flags + 1
          qs = qs '"'rd~join(toks, k, np['NEXT'] - 1)'"'
        end
        if e \== '' then if e \== from then if e \== to then do
          res = checkName(e, from, to)
          call emitName k, res, rd~join(toks, k, np['NEXT'] - 1), e
          call out '  'res
          if res~word(1) \== 'CLEAR' then do
            flags = flags + 1
            qs = qs '"'rd~join(toks, k, np['NEXT'] - 1)'"'
          end
        end
        k = np['NEXT']
        iterate
      end
    end
    /* at + an event: a place, or the act? */
    c = lex~find(toks, k, 'prep')
    if c \== .nil then if toks[k] == 'at' then do
      np = rd~parseNP(toks, k + 1)
      if np \== .nil then do
        nc = rd~refConcept(np)
        if nc \== '' then if eventC \== '' then if cs~isa(nc, eventC) then do
          phrase = rd~join(toks, k, np['NEXT'] - 1)
          call out '  ACTION OR PLACE  "'phrase'": "at" with an event can mean waiting at the place for it, or doing it now'
          call emitRef k, 'ACTION OR PLACE  ', phrase, '', ''
          flags = flags + 1
          qs = qs '"'phrase'"'
          k = np['NEXT']
          iterate
        end
      end
    end
    k = k + 1
  end
  /* what the reader could not read was not checked. "Fly to the station
     and land near the pylon" is two orders: each part is read */
  parts = .array~new
  st = 1
  do k = 2 to toks~items - 1
    if toks[k] \== 'and' then iterate
    if lex~find(toks, k + 1, 'verb') == .nil then iterate
    part = toks~section(st, k - st)~~append('.')
    parts~append(part)
    st = k + 1
  end
  parts~append(toks~section(st, toks~items - st + 1))
  pi = 0
  do part over parts
    pi = pi + 1
    /* "Delta, inspect the north pylons": the call sign says who, not what */
    if part~items > 2 then if part[2] == ',' then if rd~isName(part[1]) then part = part~section(3)
    p = rd~parseClause(part, 'order')
    if p \== .nil then if p['EVENT'] \== '' then pVerb[pi] = p['EVENT']
    if p == .nil then do
      call out '  NOT CHECKED  the reader could not parse "'rd~join(part, 1, part~items)'"; its references were checked, its meaning was not'
      unchecked = 1
    end
    else if p['NOTE'] \== '' then do
      call out '  NOT CHECKED  'p['NOTE']
      unchecked = 1
    end
  end
  call keepOpen
  call finish
end
signal off syntax
o~close
mo~close
exit 0

orderCrash:
  signal off syntax
  ocCond = condition('O')
  ocMsg = 'error'
  if ocCond \== .nil then ocMsg = 'error' ocCond['CODE'] 'at line' ocCond['POSITION']':' ocCond['ERRORTEXT']
  od = rd~orders[oi]
  on = oi
  from = od['FROM']
  to = od['TO']
  text = rd~join(od['TOKS'], 1, od['TOKS']~items)
  if \headerDone then do
    call out ''
    call out nameOf(from) '->' nameOf(to)':' text
  end
  call out '  NOT CHECKED  Boston Crab failed on this order ('ocMsg'); it says nothing about what the order means'
  call out '  NOTHING FOUND, BUT NOT FULLY CHECKED'
  mo~lineout('order|'on'|'mrName(from)'|'mrName(to)'|'text)
  mo~lineout('fail|'on'|'ocMsg)
  mo~lineout('end|'on'|NOT CHECKED')
  .error~lineout('order_check: order' on 'not checked:' ocMsg)
  oStart = oi + 1
  signal orderLoop

/* the verdict line, and the order's lines in orders.words */
finish:
  if flags > 0 then fv = 'REQUIRES CLARIFICATION'
  else if unchecked then fv = 'NOTHING FOUND, BUT NOT FULLY CHECKED'
  else fv = 'CLEAR'
  call out '  'fv
  mo~lineout('order|'on'|'mrName(from)'|'mrName(to)'|'text)
  do fi = 1 to pStart~items
    fe = toks~items
    if fi < pStart~items then fe = pStart[fi + 1] - 2
    fvb = ''
    if pVerb~hasIndex(fi) then fvb = pVerb[fi]
    if fvb == 'ACK' then do
      mo~lineout('part|'on'|'fi'|-|acknowledgement|-|'text)
      iterate
    end
    /* the verb said first in the part, if the parse gave none */
    fk = pStart[fi]
    /* (a name is not a verb: "Observatory Hill") */
    fvb2 = ''
    if fvb == '' then do
      fj = pStart[fi]
      do while fj <= fe
        fr = rd~nameRun(toks, fj)
        if fr \== .nil then do
          fj = fr['END']
          iterate
        end
        fc = lex~find(toks, fj, 'verb')
        if fc \== .nil then do
          /* a Ukrainian part's verb is its command, not "знайдено" (found)
             in the condition before it */
          if fc['E']['FEATS']~hasIndex('lang') then if wordpos(fc['E']['FEATS']['form'], 'imp inf 1sg 1pl') = 0 then do
            if fvb == '' then fvb2 = fc['E']['CONCEPT']
            fj = fj + 1
            iterate
          end
          fvb = fc['E']['CONCEPT']
          fk = fj + fc['LEN']
          leave
        end
        fj = fj + 1
      end
    end
    else do fj = pStart[fi] to fe
      fc = lex~find(toks, fj, 'verb')
      if fc \== .nil then if fc['E']['CONCEPT'] == fvb then do
        fk = fj + fc['LEN']
        leave
      end
    end
    if fvb == '' then fvb = fvb2
    /* "conduct a search", "вести пошук": a general verb takes its action
       from the noun after it; with no verb ("Пошук у районі ..."), the
       first noun says it */
    fact = fvb
    if fvb == '' | wordpos(fvb, lightC) > 0 then do
      do fj = fk to fe
        fc = lex~find(toks, fj, 'noun')
        if fc \== .nil then if eventC \== '' then if cs~isa(fc['E']['CONCEPT'], eventC) then do
          fact = fc['E']['CONCEPT']
          leave
        end
      end
    end
    /* how: clockwise, separately */
    fhow = ''
    do fj = pStart[fi] to fe
      fc = lex~find(toks, fj, 'adv ukadv')
      if fc == .nil then iterate
      /* "part" may be an adverb, but here it is a noun or verb */
      if fc['E']['POS'] == 'adv' then if lex~find(toks, fj, 'noun verb') \== .nil then iterate
      if fc['E']['CONCEPT'] \== '' then fhow = fhow cg(fc['E']['CONCEPT'])
    end
    /* "якщо ...", "if ...": the action waits on a condition (in the words) */
    do fj = pStart[fi] to fe
      if wordpos(toks[fj], 'якщо if коли when') > 0 then do
        fhow = 'if' fhow
        leave
      end
    end
    /* "не знижуйтесь", "do not descend": the command is not to be done.
       "не" negates the word after it: before the command it forbids it;
       before another verb ("кружляйте, не зупиняючись", circle without
       stopping) it says how, as "without stop" */
    do fj = pStart[fi] to fe
      if lex~find(toks, fj, 'neg ukneg') == .nil then iterate
      fnv = ''
      do fq = fj + 1 to min(fj + 2, fe)
        fc = lex~find(toks, fq, 'verb')
        if fc \== .nil then do
          fnv = fc['E']['CONCEPT']
          leave
        end
      end
      if fnv == '' | fnv == fvb then fhow = 'not' fhow
      else fhow = fhow 'without' cg(fnv)
    end
    if fhow == '' then fhow = '-'
    mo~lineout('part|'on'|'fi'|'cg(fvb)'|'cg(fact)'|'fhow~strip'|'rd~join(toks, pStart[fi], fe))
  end
  do fi = 1 to mrRefs~items
    mo~lineout('ref|'on'|'mrRefs[fi])
    if mrSay~hasIndex(fi) then mo~lineout('say|'on'|'mrSay[fi])
  end
  /* "блін", "блять": the sender is frustrated; said twice or more, very */
  ftn = 0
  do fj = 1 to toks~items
    fc = lex~find(toks, fj, 'filler')
    if fc \== .nil then if fc['E']['FEATS']~hasIndex('tone') then ftn = ftn + 1
  end
  if ftn = 1 then mo~lineout('tone|'on'|frustration|1')
  if ftn > 1 then mo~lineout('tone|'on'|extreme frustration|'ftn)
  mo~lineout('end|'on'|'fv)
  return

cg:
  use arg cgId
  if cgId == '' then return '-'
  if cs~gloss~hasIndex(cgId) then return cs~gloss[cgId]
  return cgId

mrName:
  use arg mnId
  if mnId == '' then return 'all'
  if \ents~hasIndex(mnId) then return '?'
  return ents[mnId]~name

/* one reference for orders.words: which part it is in, the verdict, the
   words, and what writer and reader can each identify */
emitRef:
  use arg erPos, erRes, erTx, erW, erR
  erP = 1
  do erI = 1 to pStart~items
    if erPos >= pStart[erI] then erP = erI
  end
  erV = erRes~left(erRes~pos('  ') - 1)
  mrRefs~append(erP'|'erV'|'erTx'|'descSet(erW)'|'descSet(erR))
  /* a Ukrainian order: the same things said in Ukrainian, for read-backs */
  if isCyr(text) then mrSay[mrRefs~items] = erP'|uk|'descSetUk(erW)'|'descSetUk(erR)
  return

emitName:
  use arg enPos, enRes, enTx, enE
  enR = enE
  if enRes~word(1) \== 'CLEAR' then enR = ''
  call emitRef enPos, enRes, enTx, enE, enR
  return

/* the things in a set, said in Ukrainian ("північно-східний пілон",
   "червоні маркери", "Observatory Hill"); - where a thing has no Ukrainian
   words yet */
descSetUk:
  use arg duSet
  duOut = ''
  do duE over duSet~subWords
    if duOut \== '' then duOut = duOut';'
    duOut = duOut || ukDesc(duE)
  end
  return duOut

ukDesc:
  use arg udE
  if ents[udE]~name \== '' then return nameOf(udE)
  udNum = 'sg'
  if ents[udE]~plural == 1 then udNum = 'pl'
  /* the noun: the thing's own concept, or the nearest one above it */
  udC = ents[udE]~concept
  udN = ''
  do while udC \== '' & udC \== .nil
    if ukN~hasIndex(udC'/'udNum) then do
      udN = ukN[udC'/'udNum]
      leave
    end
    udC = cs~parent(udC)
  end
  if udN == '' then return '-'
  udG = 'm'
  if ukG~hasIndex(udC) then udG = ukG[udC]
  udK = udG
  if udNum == 'pl' then udK = 'p'
  udAdj = ''
  udAfter = ''
  do udA over ents[udE]~attrs~subWords
    /* "the Circular Quay wharves": the name stays as it is, after the noun */
    if udA~left(2) == 'N:' then do
      do udW over udA~substr(3)~translate(' ', '_')~subWords
        udAfter = udAfter udW~left(1)~upper || udW~substr(2)
      end
      iterate
    end
    if ukA~hasIndex(udA'/'udK) then do
      udAdj = udAdj ukA[udA'/'udK]
      iterate
    end
    /* northeast: "північно-східний", the first part ending in -о */
    udW = cs~within(udA)
    if words(udW) = 2 then if ukA~hasIndex(udW~word(1)'/m') then if ukA~hasIndex(udW~word(2)'/'udK) then do
      udM = ukA[udW~word(1)'/m']
      udAdj = udAdj udM~left(udM~length - 4)'о-'ukA[udW~word(2)'/'udK]
      iterate
    end
  end
  return (udAdj udN udAfter)~space

descSet:
  use arg dsSet
  dsOut = ''
  do dsE over dsSet~subWords
    if dsOut \== '' then dsOut = dsOut';'
    dsOut = dsOut || describe(dsE)
  end
  return dsOut

/* "the adjacent water" is still the water; "the red water" picks one */
hasSlotAttr:
  use arg hsA
  do hsX over hsA~subWords
    do hsS over lex~slotConcepts~subWords
      if cs~isa(hsX, hsS) then return 1
    end
  end
  return 0

/* is the concept in a class of lexicon.src ("*abstract", "*ambient")? */
inClass:
  use arg icC, icK
  if \lex~entries~hasIndex(icK) then return 0
  do icE over lex~entries[icK]
    if cs~isa(icC, icE['CONCEPT']) then return 1
  end
  return 0

isPartNoun:
  use arg ipC
  if \lex~entries~hasIndex('*partnoun') then return 0
  do ipE over lex~entries['*partnoun']
    if cs~isa(ipC, ipE['CONCEPT']) then return 1
  end
  return 0

/* "E -423 N -402" (or N first; Cyrillic Е and Н too): east and north in
   metres. Returns the token after it, or 0 */
gridAt:
  use arg gaT, gaK
  if gaK + 3 > gaT~items then return 0
  gaA = gridAxis(gaT[gaK])
  gaB = gridAxis(gaT[gaK + 2])
  if gaA == '' | gaB == '' | gaA == gaB then return 0
  if \datatype(gaT[gaK + 1], 'W') | \datatype(gaT[gaK + 3], 'W') then return 0
  return gaK + 4

gridAxis:
  use arg gxW
  if gxW == 'e' | gxW == 'е' then return 'E'
  if gxW == 'n' | gxW == 'н' then return 'N'
  return ''

gridRef:
  /* (ukCheck reads the same token array as toks) */
  use arg grK, grE
  if gridAxis(toks[grK]) == 'E' then do
    grEast = toks[grK + 1]
    grNorth = toks[grK + 3]
  end
  else do
    grEast = toks[grK + 3]
    grNorth = toks[grK + 1]
  end
  grTx = 'E' grEast 'N' grNorth
  grRes = 'CLEAR  "'grTx'": a grid reference, the same place for everyone'
  call out '  'grRes
  call emitRef grK, grRes, grTx, '', ''
  /* writer and reader both have the place itself */
  parse value mrRefs[mrRefs~items] with grP '|' .
  mrRefs[mrRefs~items] = grP'|CLEAR|'grTx'|grid' grTx'|grid' grTx
  if mrSay~hasIndex(mrRefs~items) then mrSay[mrRefs~items] = grP'|uk|grid' grTx'|grid' grTx
  return

/* a message's open questions, kept for the acknowledgement that answers it;
   one message (section) may run to several sentences */
keepOpen:
  koKey = from'/'to
  if \openSec~hasIndex(koKey) then open[koKey] = ''
  else if openSec[koKey] \== od['SECTION'] then open[koKey] = ''
  open[koKey] = (open[koKey] qs)~strip
  openSec[koKey] = od['SECTION']
  return

/* ======================================================================= */
out:
  parse arg line
  say line
  o~lineout(line)
  return

classOf: procedure expose lex
  use arg label, pos
  c = lex~find(.Array~of(label), 1, pos)
  if c == .nil then return ''
  return c['E']['CONCEPT']

ent: procedure expose ents
  use arg v
  if \v~isA(.String) then return ''
  parse var v . '@' e
  if e == '' then e = v
  if \ents~hasIndex(e) then return ''
  return e

addTo: procedure
  use arg tbl, key, val
  if \tbl~hasIndex(key) then tbl[key] = ''
  if wordpos(val, tbl[key]) = 0 then tbl[key] = (tbl[key] val)~strip
  return

nameOf:
  use arg nid
  /* "Усім бортам", or a message with no one addressee */
  if nid == '' then return 'all'
  if \ents~hasIndex(nid) then return '?'
  nm = ''
  do wd over ents[nid]~name~subWords
    nm = nm wd~left(1)~upper||wd~substr(2)
  end
  return nm~strip

/* "the Russian guns": a full description every time, never "the guns" */
describe:
  use arg did
  de = ents[did]
  if de~name \== '' then return nameOf(did)
  dd = 'the'
  if de~attrs \== '' then dd = dd rz~adjList(de~attrs)
  return dd rz~noun(de~concept, de~plural == 1)

/* what a person can identify that the reference could mean: anything in the
   situation, less what the situation says he cannot see (open world, as the
   reader's preconditions are: what is not ruled out is not ruled out) */
candidates:
  use arg np, who
  core = np['CORE']
  found = ''
  do e over ents~allIndexes~sortWith(.CaselessComparator~new)
    if hidden~hasIndex(who) then if wordpos(e, hidden[who]) > 0 then iterate
    ok = cs~isa(ents[e]~concept, core['CONCEPT'])
    /* "the wharf" is not "the Circular Quay wharves": one is not many
       (a kind said of a group, "the gunners were enemies", still counts) */
    if ok then if core['PLURAL'] \== 1 then if ents[e]~plural == 1 then if \oneOfGroup then ok = 0
    /* (looking for the group a singular could be one of) */
    if ok then if oneOfGroup then if ents[e]~plural \== 1 then ok = 0
    if \ok then if kinds~hasIndex(e) then do kc over kinds[e]~subWords
      if cs~isa(kc, core['CONCEPT']) then ok = 1
    end
    if \ok then iterate
    if \nameModsMatch(e, core['ATTRS']) then iterate
    found = found e
  end
  /* "the Circular Quay wharves" are the group the situation calls that, not
     also the east wharf that is one of the things at Circular Quay: a
     plural takes single things only when no group fits */
  if core['PLURAL'] == 1 then do
    grpOnly = ''
    do e over found~subWords
      if ents[e]~plural == 1 then grpOnly = grpOnly e
    end
    if grpOnly \== '' then found = grpOnly
  end
  return found~strip

/* "the Walsh Bay wharves": the name before the noun is either the thing's
   own name part ("the Circular Quay wharves") or the named place it is at,
   near or in ("the finger wharves were at Walsh Bay") */
nameModsMatch:
  /* labels share the caller's variables, and nameEnt loops on e: keep ours */
  use arg nmE, nmAttrs
  nmRest = ''
  nmOk = 1
  do nmA over nmAttrs~subWords
    if nmA~left(2) \== 'N:' then do
      nmRest = nmRest nmA
      iterate
    end
    if rd~attrsMatch(ents[nmE], nmA) then iterate
    nmPl = nameEnt(nmA~substr(3)~translate(' ', '_'))
    nmLc = ents[nmE]~loc
    parse var nmLc . '@' nmLe
    if nmPl == '' | nmLe \== nmPl then nmOk = 0
  end
  e = nmE
  if \nmOk then return 0
  /* "the north pylon" fits the northeast pylon and the northwest pylon:
     a compass value falls within the north (concepts.src, within=) */
  do nmA over nmRest~subWords
    if wordpos(nmA, ents[nmE]~attrs) > 0 then iterate
    nmIn = 0
    do nmB over ents[nmE]~attrs~subWords
      if wordpos(nmA, cs~within(nmB)) > 0 then nmIn = 1
    end
    if \nmIn then return 0
  end
  return 1

/* the recipient's own command is what an order's plain "the cavalry" means */
preferCommand:
  use arg set, recipient
  if \cmd~hasIndex(recipient) then return set
  mine = ''
  do e over set~subWords
    if wordpos(e, cmd[recipient]) > 0 then mine = mine e
  end
  if words(mine) = 1 then return mine~strip
  return set

listOf:
  use arg set, who
  t = ''
  do e over set~subWords
    if t \== '' then t = t 'and'
    t = t describe(e)
    if arg(2, 'E') then if mapNote~hasIndex(who'/'e) then t = t '('mapNote[who'/'e]')'
  end
  return t~strip

/* only the things the situation puts at, near or in a place */
placedAt:
  use arg set, wh
  keep = ''
  do e over set~subWords
    lc = ents[e]~loc
    parse var lc . '@' le
    if le == wh then keep = keep e
  end
  return keep~strip

/* "Blues Tower": the names that hold every word of it ("Blues Point Tower"),
   said beside an unknown name so the writer can see what he may have meant */
nameNear:
  use arg nnTx
  nnOut = ''
  do nnE over ents~allIndexes~sortWith(.CaselessComparator~new)
    nnNm = ents[nnE]~name
    if nnNm == '' then iterate
    nnAll = 1
    do nnW over nnTx~subWords
      if wordpos(nnW, nnNm) = 0 then nnAll = 0
    end
    if nnAll then nnOut = nnOut nameOf(nnE)','
  end
  if nnOut == '' then return ''
  return '; nearest:' nnOut~strip~strip('T', ',')

/* the one thing in the situation a reference means, or "" */
refEnt:
  use arg rnp
  if rnp['KIND'] == 'name' then return nameEnt(rnp['LABEL'])
  if \rnp~hasIndex('CORE') then return ''
  found = ''
  do e over ents~allIndexes
    if \cs~isa(ents[e]~concept, rnp['CORE']['CONCEPT']) then iterate
    if \nameModsMatch(e, rnp['CORE']['ATTRS']) then iterate
    found = found e
  end
  if words(found) \= 1 then return ''
  return found~strip

/* "Lord Raglan" is the Raglan of the situation: an exact name first, then
   the one entity whose name is one of the words (a title or first name
   added); two such, or none, is no answer */
nameEnt:
  use arg lab
  do e over ents~allIndexes
    if ents[e]~name == lab then return e
  end
  one = ''
  do e over ents~allIndexes
    if ents[e]~name == '' then iterate
    if wordpos(ents[e]~name, lab) = 0 then iterate
    /* "Sydney Opera House" is the Opera House and "Lord Raglan" is Raglan,
       but "Blues Tower" is a tower, so not a place called "Blues": the
       last word, which says what kind of thing it is, must be the same */
    if ents[e]~name~word(words(ents[e]~name)) \== lab~word(words(lab)) then iterate
    if one \== '' then return ''
    one = e
  end
  return one

/* a named place: one thing by its name, so the question is only whether
   the recipient can see it */
checkName:
  use arg e, from, to
  ph = '"'nameOf(e)'"'
  if hidden~hasIndex(to) then if wordpos(e, hidden[to]) > 0 then do
    note = ''
    if mapNote~hasIndex(to'/'e) then note = ' ('mapNote[to'/'e]')'
    return 'NOT VISIBLE  'ph':' nameOf(to) 'cannot see it'note
  end
  note = ''
  if mapNote~hasIndex(to'/'e) then note = ' ('mapNote[to'/'e]')'
  return 'CLEAR  'ph': a named place'note

/* "the British guns" in bind.words: the one thing in the situation it means */
bindTo:
  use arg phrase
  bt = rd~tokens(phrase'.')
  bnp = rd~parseNP(bt, 1)
  if bnp == .nil then return ''
  if bnp['KIND'] == 'name' then do
    do e over ents~allIndexes
      if ents[e]~name == bnp['LABEL'] then return e
    end
    return ''
  end
  if \bnp~hasIndex('CORE') then return ''
  found = ''
  do e over ents~allIndexes
    if \cs~isa(ents[e]~concept, bnp['CORE']['CONCEPT']) then iterate
    if \rd~attrsMatch(ents[e], bnp['CORE']['ATTRS']) then iterate
    found = found e
  end
  if words(found) \= 1 then return ''
  return found~strip

checkRef:
  use arg np, from, to
  adjs = ''
  if np['CORE']['ATTRS'] \== '' then adjs = rz~adjList(np['CORE']['ATTRS']~changeStr(' and ', ' '))' '
  phrase = '"the' adjs || rz~noun(np['CORE']['CONCEPT'], np['CORE']['PLURAL'] == 1)'"'
  w = preferCommand(candidates(np, from), to)
  r = preferCommand(candidates(np, to), to)
  if np['WHERE'] \== '' then phrase = phrase~left(phrase~length - 1) np['WHERETEXT']'"'
  if np['WHERE'] \== '' then do
    w = placedAt(w, np['WHERE'])
    r = placedAt(r, np['WHERE'])
  end
  /* "the water", "на воді": always there out of doors */
  if words(w) = 0 then if words(r) = 0 then if \hasSlotAttr(np['CORE']['ATTRS']) then if inClass(np['CORE']['CONCEPT'], '*ambient') then
    return 'CLEAR  'phrase': always there (water, sky, ground), nothing to choose between'
  /* "the red marker" when the situation has only the red markers: one of
     them, and which one is not said */
  if np['CORE']['PLURAL'] \== 1 then if words(w) = 0 then do
    oneOfGroup = 1
    gw = candidates(np, from)
    oneOfGroup = 0
    if np['WHERE'] \== '' then gw = placedAt(gw, np['WHERE'])
    if gw \== '' then return 'AMBIGUOUS  'phrase': one of' listOf(gw, from)'; which one is not said'
  end
  /* "the north pylons" with two north pylons: the plural names the pair */
  if np['CORE']['PLURAL'] == 1 then if words(w) > 1 | words(r) > 1 then do
    grp = 1
    do grpE over (w r)~subWords
      if ents[grpE]~plural == 1 then grp = 0
    end
    if grp then do
      if to == '' | w == r then return 'CLEAR  'phrase': all of' listOf(w, from)
      if words(r) = 0 then return 'NOT VISIBLE  'phrase': for' nameOf(from) 'it is' listOf(w, from)';' nameOf(to) 'can see nothing it could mean'
      return 'MEANS DIFFERENT THINGS  'phrase':' nameOf(from) 'means' listOf(w, from)', but' nameOf(to) 'will take' listOf(r, to)
    end
  end
  /* to all: only what the writer can see is known */
  if to == '' then do
    if words(w) = 0 then return 'NO REFERENT  'phrase': nothing in the situation could be meant'
    if words(w) > 1 then return 'AMBIGUOUS  'phrase': it fits' words(w) 'things:' listOf(w, from)
    return 'CLEAR  'phrase': it is' listOf(w, from)
  end
  if words(w) = 0 then if words(r) = 0 then return 'NO REFERENT  'phrase': neither' nameOf(from) 'nor' nameOf(to) 'can see anything it could mean'
  if words(r) = 0 then return 'NOT VISIBLE  'phrase': for' nameOf(from) 'it is' listOf(w, from)';' nameOf(to) 'can see nothing it could mean'
  if words(r) > 1 then return 'AMBIGUOUS  'phrase':' nameOf(to) 'can see' words(r) 'things it could mean:' listOf(r, to)
  if words(w) > 1 then return 'WRITER AMBIGUOUS  'phrase': it fits' words(w) 'things' nameOf(from) 'can see ('listOf(w, from)');' nameOf(to) 'can see only' listOf(r, to)', so he will take it as that'
  if words(w) = 0 then return 'CLEAR  'phrase': for' nameOf(to) 'it is' listOf(r, to) '(' || nameOf(from) 'cannot see it)'
  if w \== r then return 'MEANS DIFFERENT THINGS  'phrase':' nameOf(from) 'means' listOf(w, from)', but' nameOf(to) 'will take' listOf(r, to)
  return 'CLEAR  'phrase': both mean' listOf(r, to)

/* ======================================================================= */
/* Ukrainian orders. The words differ; the concepts are the same ones the  */
/* English words have (lexicon_uk.src), so every check below is the        */
/* English check. Ukrainian has no "the": a noun phrase is a reference to  */
/* check when it names a kind the situation has things of, carries a       */
/* value of a slot ("північний", north), or is a name. Other noun phrases  */
/* (пошук, a search; завдання, a task) say what to do, not which thing.    */
/* Labels share the caller's variables: everything here starts with u.     */
isCyr:
  use arg uS
  return uS~pos('D0'x) > 0 | uS~pos('D1'x) > 0 | uS~pos('D2'x) > 0

ukCheck:
  use arg uT, uFrom, uTo
  uObjNext = 0
  uK = 1
  uUnread = ''
  uLastNoun = ''
  uPrev = ''
  do while uK <= uT~items
    uW = uT[uK]
    if verify(uW, '.,!?:;—-') = 0 then do
      uObjNext = 0
      uK = uK + 1
      iterate
    end
    /* "(North Pylon)": an English gloss in brackets */
    if uW == '(' then do
      uJ = uK + 1
      do while uJ <= uT~items
        if uT[uJ] == ')' then leave
        uJ = uJ + 1
      end
      if uJ > uK + 1 then call ukGloss uT~section(uK + 1, uJ - uK - 1)
      uK = uJ + 1
      iterate
    end
    if uW == ')' then do
      uK = uK + 1
      iterate
    end
    /* a grid reference */
    uGe = gridAt(uT, uK)
    if uGe > 0 then do
      call gridRef uK, uGe
      uK = uGe
      iterate
    end
    /* a number ("350 м") is read as it is */
    if datatype(uW, 'N') then do
      uK = uK + 1
      iterate
    end
    /* a name in Latin letters: Sydney Opera House, Blues Tower, Alpha */
    if \isCyr(uW) then if rd~isName(uW) | (rd~nameRun(uT, uK) \== .nil) then do
      uNp = .nil
      if rd~isName(uW) | (rd~nameRun(uT, uK) \== .nil) then uNp = rd~parseNP(uT, uK)
      if uNp \== .nil then do
        uTx = rd~join(uT, uK, uNp['NEXT'] - 1)
        if uNp['KIND'] == 'name' then do
          call ukName uNp['LABEL'], uTx
          uK = uNp['NEXT']
          iterate
        end
        if uNp['KIND'] == 'def' then do
          call ukNP uNp['CORE']['CONCEPT'], uNp['CORE']['ATTRS'], uNp['CORE']['PLURAL'] == 1, uTx
          uK = uNp['NEXT']
          iterate
        end
      end
      /* not a name after all: an English word, read below like the rest */
    end
    /* a name said in Ukrainian: Наземний Контроль, Сіднейська гавань */
    uC = lex~find(uT, uK, 'nameform')
    if uC \== .nil then do
      call ukName uC['E']['FEATS']['name'], rd~join(uT, uK, uK + uC['LEN'] - 1)
      uK = uK + uC['LEN']
      iterate
    end
    /* adjectives (perhaps joined by та/і), then a noun */
    uAdjs = .array~new
    uJ = uK
    uConj = 0
    do forever
      uA = lex~find(uT, uJ, 'adj')
      /* "до base": a word that is a noun too, with no noun after it, is the noun */
      if uA \== .nil then if lex~find(uT, uJ, 'noun') \== .nil then if lex~find(uT, uJ + uA['LEN'], 'noun') == .nil then uA = .nil
      if uA \== .nil then do
        uAdjs~append(uA)
        uJ = uJ + uA['LEN']
        iterate
      end
      if uAdjs~items > 0 then if lex~find(uT, uJ, 'ukconj') \== .nil then if lex~find(uT, uJ + 1, 'adj') \== .nil then do
        uConj = 1
        uJ = uJ + 1
        iterate
      end
      leave
    end
    uN = lex~find(uT, uJ, 'noun')
    /* "між піддонами" (between the pallets): a thing to steer by must be
       in the situation, as with "the" in English; so must the thing a
       command acts on ("уникайте ворожих дронів", avoid the hostile
       drones), except what is searched for, which may not be known yet */
    uForce = uObjNext
    if uK > 1 then do
      uPc = lex~find(uT, uK - 1, 'ukprep')
      if uPc \== .nil then if uPc['E']['FEATS']~hasIndex('place') then uForce = 1
    end
    if uAdjs~items > 0 | uN \== .nil then do
      if uN \== .nil then do
        uNoun = uN['E']['CONCEPT']
        uPl = (uN['E']['FEATS']['num'] == 'pl')
        uEnd = uJ + uN['LEN']
      end
      else do
        /* the noun left out: "від східного до західного причалу" takes
           the noun ahead; "від східного причалу до західного" the one before */
        uEnd = uJ
        uNoun = ''
        if lex~find(uT, uJ, 'ukprep') \== .nil then do
          uJ2 = uJ + 1
          do while lex~find(uT, uJ2, 'adj') \== .nil
            uJ2 = uJ2 + lex~find(uT, uJ2, 'adj')['LEN']
          end
          uN2 = lex~find(uT, uJ2, 'noun')
          if uN2 \== .nil then uNoun = uN2['E']['CONCEPT']
        end
        if uNoun == '' then uNoun = uLastNoun
        /* only a value says "the west one": "будьте обережні" (be careful)
           is said of the drone, not of a careful thing */
        uSlot = 0
        do uA over uAdjs
          do uS over lex~slotConcepts~subWords
            if cs~isa(uA['E']['CONCEPT'], uS) then uSlot = 1
          end
        end
        if \uSlot then uNoun = ''
        uPl = (uAdjs[uAdjs~items]['E']['FEATS']['num'] == 'pl')
      end
      uTx = rd~join(uT, uK, uEnd - 1)
      if uNoun \== '' then do
        /* "північний та південний пілони": the north one and the south one */
        if uConj & uPl then do uA over uAdjs
          call ukNP uNoun, uA['E']['CONCEPT'], 0, uTx, uForce
        end
        else do
          uAt = ''
          do uA over uAdjs
            uAt = uAt uA['E']['CONCEPT']
          end
          call ukNP uNoun, uAt~strip, uPl, uTx, uForce
        end
        uObjNext = 0
        uLastNoun = uNoun
      end
      uK = uEnd
      iterate
    end
    uC = lex~find(uT, uK, 'verb ukprep ukconj ukfunc ukadv ukneg formula addrall prep det conj filler')
    if uC \== .nil then do
      if uC['E']['POS'] == 'verb' then do
        uObjNext = 0
        if uC['E']['FEATS']~hasIndex('form') then if uC['E']['FEATS']['form'] == 'imp' then if \inClass(uC['E']['CONCEPT'], '*searchverb') then uObjNext = 1
      end
      if uC['E']['POS'] == 'ukprep' then uObjNext = 0
      uK = uK + uC['LEN']
      iterate
    end
    uUnread = uUnread uW
    uK = uK + 1
  end
  if uUnread \== '' then do
    call out '  NOT CHECKED  unread words:' uUnread~strip
    unchecked = 1
  end
  return

/* one noun phrase: check it if it is a reference */
ukNP:
  use arg unC, unAt, unPl, unTx, unForce = 0
  uPrev = unC'/'unAt
  /* "західну частину поля": a part of the field is there if the field is;
     the field, said next, is what is checked */
  if isPartNoun(unC) then return
  unRef = 0
  do unA over unAt~subWords
    do unS over lex~slotConcepts~subWords
      if cs~isa(unA, unS) then unRef = 1
    end
  end
  if \unRef then do unE over ents~allIndexes
    if cs~isa(ents[unE]~concept, unC) then unRef = 1
  end
  if \unRef then if unForce then if \inClass(unC, '*abstract') then unRef = 1
  if \unRef then return
  unNp = .Directory~new
  unCore = .Directory~new
  unCore['CONCEPT'] = unC
  unCore['ATTRS'] = unAt
  unCore['PLURAL'] = unPl
  unNp['CORE'] = unCore
  unNp['WHERE'] = ''
  unRes = checkRef(unNp, uFrom, uTo)
  call emitRef uK, unRes, unTx, w, r
  unPos = unRes~pos('":')
  if unPos > 0 then unRes = unRes~left(unPos) '('unTx')'unRes~substr(unPos + 1)
  call out '  'unRes
  if unRes~word(1) \== 'CLEAR' then do
    flags = flags + 1
    qs = qs '"'unTx'"'
  end
  return

/* a name: does the situation have it, and can the recipient see it? */
ukName:
  use arg umLab, umTx
  umE = nameEnt(umLab)
  if umE == '' then umE = nameEnt(umTx)
  if umE == '' then do
    call out '  UNKNOWN NAME  "'umTx'": the situation has no place or person of that name'nameNear(umTx)
    call emitRef uK, 'UNKNOWN NAME  ', umTx, '', ''
    flags = flags + 1
    qs = qs '"'umTx'"'
    return
  end
  if umE == uFrom | umE == uTo then return
  /* a call sign named in a message to all is an addressee, not a place */
  if uTo == '' then if rd~castNames~hasIndex(ents[umE]~name) then return
  umRes = checkName(umE, uFrom, uTo)
  call emitName uK, umRes, umTx, umE
  if umTx \== nameOf(umE) then do
    umPos = umRes~pos('":')
    if umPos > 0 then umRes = umRes~left(umPos) '('umTx')'umRes~substr(umPos + 1)
  end
  call out '  'umRes
  if umRes~word(1) \== 'CLEAR' then do
    flags = flags + 1
    qs = qs '"'umTx'"'
  end
  return

/* "(North Pylon)" after "північний пілон": the same reference in English is
   not checked twice; anything else in brackets is checked as English */
ukGloss:
  use arg ugIn
  ugCore = rd~parseCore(ugIn, 1)
  if ugCore \== .nil then if ugCore['NEXT'] > ugIn~items then do
    if ugCore['CONCEPT']'/'ugCore['ATTRS'] == uPrev then return
    call ukNP ugCore['CONCEPT'], ugCore['ATTRS'], ugCore['PLURAL'] == 1, rd~join(ugIn, 1, ugIn~items)
    return
  end
  ugNp = rd~parseNP(ugIn, 1)
  if ugNp \== .nil then if ugNp['KIND'] == 'name' then do
    call ukName ugNp['LABEL'], rd~join(ugIn, 1, ugIn~items)
    return
  end
  uUnread = uUnread '('rd~join(ugIn, 1, ugIn~items)')'
  return

::requires 'reader.cls'
::requires 'realiser.cls'
