/* testimony.rex - weigh witness statements and records with Reasoned Thought.   */
/* The reader turns each statement into claims by its witness (TESTIMONY) and   */
/* each official record into narration by a document (DOCUMENTARY). This script */
/* asks one kind of question of them: where was each named person, at each      */
/* place the sources name? Every location claim becomes a ground on an AT       */
/* proposition; Reasoned Thought's ordinal combiner decides. Nothing here        */
/* counts votes, and no gloss or English word is read: places, crimes and times */
/* are found by concept class.                                                  */
/*                                                                              */
/* Declared policies (each ground says which one made it):                      */
/*  ONE-PLACE     a dated claim that p was at Y rebuts p at X, for every other  */
/*                place X whose time window overlaps the claim's.               */
/*  HEARSAY       "I heard that..." / "he told me..." proves what was said, not */
/*                what happened: binding HEARSAY, which no AT proposition takes.*/
/*  SELF-SERVING  a claim that keeps its own witness away from a crime place is */
/*                undercut at its own tier (interest).                          */
/*  PARTIALITY    a claim that keeps someone the witness has a stated relation  */
/*                to (brother, girlfriend) away from a crime place is undercut. */
/*  ACCOMPLICE    once a witness is settled at a crime place, his claims that   */
/*                put others there are undercut: he gains by sharing blame.     */
/*  IMPEACHMENT   a witness one of whose claims rebuts a settled proposition has */
/*                every other claim undercut at its own tier.                   */
/*  AGAINST-INTEREST  a claim that puts its own witness at a crime place is     */
/*                noted, never upgraded: an admission lends no weight to the    */
/*                denial beside it (Tom Dyer: "I nicked a candy bar but I did    */
/*                not shoot the sheriff").                                      */
/* Usage: rexx testimony.rex storydir                                           */
/* Architecture: Tom Dyer. Reasoned Thought: Claude (Opus 4.8) / ChatGPT.       */
/* This file: Claude (Opus 5.5).                                                */
parse arg dir .
if dir == '' then dir = '.'
rd = .Reader~new(dir)
rd~readFile(dir'/story.txt')
cs = rd~cs
lex = rd~lex
ents = rd~ents
rz = .Realiser~new(rd)
nc = .Directory~new
placeC = classOf(lex, '*place', 'placeclass')
crimeC = classOf(lex, '*crime', 'crimeclass')
moveC = classOf(lex, '*move', 'moveclass')
clockC = lex~clockConcept
nameC = lex~nameConcept

/* ---------------------------------------------------------------- 1. claims */
claims = .Array~new
scene = .StringTable~new          /* source -> the place its account is at now */
crimePlaces = ''
suspects = ''                     /* said to have done, or denying, a crime */
claimSeq = 0
recNo = .StringTable~new
do pid over rd~order
  p = rd~props[pid]
  if \p~hasIndex('TIER') then iterate
  src = sourceOf(p)
  call crimeCheck p
  /* the witness's own claim */
  call claimsOf p, src, p['TIER'], 'GENERAL', pid, '', p
  /* a reported clause: hearsay, unless the witness is retelling his own words */
  c = p['ROLES']['content']
  if c~isA(.String) then if rd~props~hasIndex(c) then do
    cp = rd~props[c]
    call crimeCheck cp
    if p~hasIndex('REPORT') then do
      teller = entOf(p['ROLES']['agent'])
      own = .false
      if teller == p['SPEAKER'] then if p['ROLES']~hasIndex('recipient') then own = .true
      if own then call claimsOf cp, src, p['TIER'], 'GENERAL', pid, 'his own words, retold', p
      else call claimsOf cp, src, p['TIER'], 'HEARSAY', pid, 'reported to the witness, not seen', p
    end
  end
end

/* a suspect is someone a source says did (or denies doing) a crime; being at
   the place of one is not enough (the bank's own staff were there too) */

/* time window of each place: every dated presence any source gives there */
win = .StringTable~new
do cl over claims
  if cl['POL'] \== '+' then iterate
  if cl['LO'] == '' then iterate
  pl = cl['PLACE']
  if \win~hasIndex(pl) then win[pl] = cl['LO'] cl['HI']
  else do
    parse value win[pl] with lo hi
    win[pl] = min(lo, cl['LO']) max(hi, cl['HI'])
  end
end

/* ---------------------------------------------------------- 2. propositions */
net = .ThoughtNetwork~new
propIds = .Array~new
propOf = .StringTable~new
persons = ''
places = ''
do cl over claims
  if wordpos(cl['PERSON'], persons) = 0 then persons = persons cl['PERSON']
  if wordpos(cl['PLACE'], places) = 0 then places = places cl['PLACE']
end
do pr over persons~subWords
  do pl over places~subWords
    id = 'AT.'ents[pr]~name'.'placeWord(pl)
    propOf[pr'/'pl] = id
    propIds~append(id)
    net~propose(id, ents[pr]~name~upper~left(1)||ents[pr]~name~substr(2) 'was at the' placeWord(pl) windowText(pl), 'DOCUMENTARY', 'TESTIMONY')
  end
end

/* ---------------------------------------------------------- 3. grounds, pass 1 */
utt = .StringTable~new
gInfo = .StringTable~new          /* ground id -> source tier target kind */
gSeq = 0
do cl over claims
  tgt = propOf[cl['PERSON']'/'cl['PLACE']]
  note = cl['TEXT']
  if cl['NOTE'] \== '' then note = note '('cl['NOTE']')'
  if cl['POL'] == '+' then do
    if cl['SELF'] then if wordpos(cl['PLACE'], crimePlaces) > 0 then note = note '[AGAINST-INTEREST: noted, not upgraded]'
    call ground cl['SRC'], 'SUPPORT', cl['TIER'], tgt, '', cl['BINDS'], note, cl
    /* one place at a time */
    if cl['LO'] \== '' then do x over places~subWords
      if x == cl['PLACE'] then iterate
      if \win~hasIndex(x) then iterate
      parse value win[x] with wlo whi
      if cl['HI'] < wlo | cl['LO'] > whi then iterate
      call ground cl['SRC'], 'REBUT', cl['TIER'], propOf[cl['PERSON']'/'||x], '', cl['BINDS'], '[ONE-PLACE] at the' placeWord(cl['PLACE']) clockText(cl['LO'], cl['HI'])':' note, cl
    end
    /* "alone": nobody else who is said to have been there was */
    if cl['ALONE'] then do q over persons~subWords
      if q == cl['PERSON'] then iterate
      if \saidThere(q, cl['PLACE']) then iterate
      call ground cl['SRC'], 'REBUT', cl['TIER'], propOf[q'/'cl['PLACE']], '', cl['BINDS'], '"alone":' note, cl
    end
  end
  else call ground cl['SRC'], 'REBUT', cl['TIER'], tgt, '', cl['BINDS'], 'denies:' note, cl
end
/* interest undercuts, decided by whom the claim helps: a ground helps q if it
   rebuts q at a crime place, or supports q somewhere else during a crime's window.
   Interest attaches to the statement, not to one proposition: when a sentence
   is an alibi for the witness, everything that sentence claims is discounted
   ("I was at the supermarket with Emma" is Noah's alibi, Emma included). */
pol = .Utterance~new('POLICY', 'declared assessment policy')
why = .StringTable~new            /* claim -> policy text */
do gid over gInfo~allIndexes~sortWith(.CaselessComparator~new)
  gi = gInfo[gid]
  q = gi['PERSON']
  if \helps(gi) then iterate
  if wordpos(q, suspects) = 0 then iterate
  if why~hasIndex(gi['CLAIM']) then iterate
  if q == gi['WITNESS'] then why[gi['CLAIM']] = 'SELF-SERVING|an alibi or denial for the witness himself'
  else if related(gi['WITNESS'], q) then why[gi['CLAIM']] = 'PARTIALITY|helps' nameOf(q)', and' relText(gi['WITNESS'], q)
end
/* accomplice: a suspect whom any first-hand claim (his own included) puts at a
   crime place gains by sharing blame, so his claims putting others there are
   discounted (the support and the one-place rebuts the same claim makes) */
do gid over gInfo~allIndexes~sortWith(.CaselessComparator~new)
  gi = gInfo[gid]
  if why~hasIndex(gi['CLAIM']) then iterate
  w = gi['WITNESS']
  if gi['CLAIMPOL'] \== '+' then iterate
  if w == '' then iterate
  if wordpos(w, suspects) = 0 then iterate
  if gi['PERSON'] == w then iterate
  if wordpos(gi['CLAIMPLACE'], crimePlaces) = 0 then iterate
  if \saidThere(w, gi['CLAIMPLACE']) then iterate
  why[gi['CLAIM']] = 'ACCOMPLICE|'nameOf(w) 'is a suspect put at the' placeWord(gi['CLAIMPLACE'])', and gains by sharing blame'
end
do gid over gInfo~allIndexes~sortWith(.CaselessComparator~new)
  gi = gInfo[gid]
  if \why~hasIndex(gi['CLAIM']) then iterate
  parse value why[gi['CLAIM']] with wpol '|' wtext
  call undercut pol, gid, wpol, wtext
end
call admitAll

/* ---------------------------------------------------------- 4. pass 2: settled facts */
settled = .StringTable~new
do id over propIds
  d = net~assess(id)
  if d['settled'] then settled[id] = 1
end
pol2 = .Utterance~new('POLICY-2', 'policy applied to settled facts')
impeached = ''
do gid over gInfo~allIndexes~sortWith(.CaselessComparator~new)
  gi = gInfo[gid]
  if gi['KIND'] == 'REBUT' then if settled~hasIndex(gi['TARGET']) then do
    w = gi['SOURCE']
    if wordpos(w, impeached) = 0 then impeached = impeached w
    gi['IMPEACHES'] = 1
  end
end
do gid over gInfo~allIndexes~sortWith(.CaselessComparator~new)
  gi = gInfo[gid]
  if wordpos(gi['SOURCE'], impeached) > 0 then if gi['IMPEACHES'] \== 1 then call undercut pol2, gid, 'IMPEACHMENT', nameOf(gi['WITNESS']) 'is shown wrong by a settled fact'
end
net~admit(pol2)

/* ---------------------------------------------------------- 5. report */
o = .Stream~new(dir'/out/testimony.txt')~~open('write replace')
call out 'Sources:'
do s over utt~allIndexes~sortWith(.CaselessComparator~new)
  if s~left(6) == 'POLICY' then iterate
  mark = ''
  if wordpos(s, impeached) > 0 then mark = '  IMPEACHED'
  call out '  'left(s, 10) utt[s]~text mark
end
call out 'Crime places:' placeList(crimePlaces)
sl = ''
do x over suspects~subWords
  sl = sl nameOf(x)
end
call out 'Suspects:' sl~strip '(a source says they did, or they deny, a crime)'
call out ''
do id over propIds
  d = net~assess(id)
  if d['live']~items + d['defeated']~items + d['ineligible']~items = 0 then iterate
  ans = answerOf(d)
  call out left(id, 24) left(d['stance'], 12) left(d['status'], 11) ans
  call out '    'd['statement']
  do g over net~proposition(id)~grounds
    if g~kind == 'UNDERCUT' then iterate
    st = 'LIVE'
    if d['defeated']~hasItem(g~id) then st = 'UNDERCUT'
    if d['ineligible']~hasItem(g~id) then st = 'HEARSAY'
    by = ''
    do u over net~proposition(id)~grounds
      if u~kind \== 'UNDERCUT' then iterate
      if u~undercutsGroundId == g~id then by = by u~note
    end
    call out '      'left(g~id, 6) left(g~kind, 7) left(g~className, 11) left(st, 8) g~note
    if by \== '' then if st == 'UNDERCUT' then call out '                                       by' by~strip
  end
end
call out ''
call out 'Coverage: claims' claims~items', sentences unread' rd~unread~items '(see unread.txt)'
o~close
exit 0

/* ======================================================================= */
out:
  parse arg line
  say line
  o~lineout(line)
  return

classOf: procedure
  use arg lex, label, pos
  t = .Array~of(label)
  c = lex~find(t, 1, pos)
  if c == .nil then return ''
  return c['E']['CONCEPT']

sourceOf:
  use arg sp
  if sp['TIER'] == 'DOCUMENTARY' then do
    if \recNo~hasIndex(sp['SECTION']) then recNo[sp['SECTION']] = recNo~items + 1
    return 'RECORD'recNo[sp['SECTION']]
  end
  return nameOf(sp['SPEAKER'])~upper

nameOf:
  use arg nid
  if \ents~hasIndex(nid) then return '?'
  nm = ents[nid]~name
  return nm~left(1)~upper||nm~substr(2)

placeWord:
  use arg plid
  return rz~noun(ents[plid]~concept, .false)

entOf: procedure expose ents
  use arg v
  if \v~isA(.String) then return ''
  parse var v . '@' e
  if e == '' then e = v
  if e~left(6) == 'CLOCK:' then return e
  if \ents~hasIndex(e) then return ''
  return e

/* a crime's place: where anything in a crime class happens, whoever says so */
crimeCheck:
  use arg cp
  if crimeC == '' then return
  if cp['EVENT'] == '' then return
  if \cs~isa(cp['EVENT'], crimeC) then return
  /* "I did not rob the bank": a denial still shows who is accused */
  ag = entOf(cp['ROLES']['agent'])
  if ag \== '' then if ag~left(6) \== 'CLOCK:' then do x over rd~membersOf(ag)~subWords
    if wordpos(x, suspects) = 0 then suspects = (suspects x)~strip
  end
  do r over .array~of('patient', 'at', 'to')
    e = entOf(cp['ROLES'][r])
    if e == '' then iterate
    if e~left(6) == 'CLOCK:' then iterate
    if \cs~isa(ents[e]~concept, placeC) then iterate
    if wordpos(e, crimePlaces) = 0 then crimePlaces = (crimePlaces e)~strip
  end
  return

/* the location claims one prop makes */
claimsOf:
  use arg cp, csrc, ctier, cbinds, cpid, cnote, ctextp
  roles = cp['ROLES']
  who = ''
  a = entOf(roles['agent'])
  if a == '' then a = entOf(roles['holder'])
  if a \== '' then if a~left(6) \== 'CLOCK:' then who = rd~membersOf(a)
  if cp['POL'] == '+' then do
    m = entOf(roles['company'])
    if m \== '' then do x over rd~membersOf(m)~subWords
      if wordpos(x, who) = 0 then who = who x
    end
  end
  /* the place */
  plc = ''
  do r over .array~of('to', 'at', 'at2', 'path')
    e = entOf(roles[r])
    if e == '' then iterate
    if e~left(6) == 'CLOCK:' then iterate
    if cs~isa(ents[e]~concept, placeC) then do
      plc = e
      leave
    end
    /* near the drinks, next to me: somewhere in the place being told of */
    if scene~hasIndex(csrc) then do
      plc = scene[csrc]
      leave
    end
  end
  /* left the supermarket, robbed the bank: a place as the object of a movement
     or a crime is where the doer was ("I remember the supermarket" is not) */
  if plc == '' then if cp['POL'] == '+' then if cp['EVENT'] \== '' then if cs~isa(cp['EVENT'], moveC) | cs~isa(cp['EVENT'], crimeC) then do
    e = entOf(roles['patient'])
    if e \== '' then if e~left(6) \== 'CLOCK:' then if cs~isa(ents[e]~concept, placeC) then plc = e
  end
  /* arrested outside the bank: who is acted on is where the act is */
  if plc \== '' then if cp['POL'] == '+' then do
    e = entOf(roles['patient'])
    if e \== '' then if e~left(6) \== 'CLOCK:' then if cs~isa(ents[e]~concept, nameC) then do x over rd~membersOf(e)~subWords
      if wordpos(x, who) = 0 then who = who x
    end
  end
  /* times */
  lo = ''
  hi = ''
  do r over .array~of('time', 'time2', 'before', 'until')
    e = entOf(roles[r])
    if e == '' then iterate
    if e~left(6) \== 'CLOCK:' then iterate
    mn = e~substr(7)
    if lo == '' then do
      lo = mn
      hi = mn
    end
    else do
      lo = min(lo, mn)
      hi = max(hi, mn)
    end
  end
  /* "we stayed until 3:35": no place named, so the place the account is at */
  if plc == '' then if lo \== '' then if scene~hasIndex(csrc) then plc = scene[csrc]
  if plc == '' then return
  if cbinds == 'GENERAL' then scene[csrc] = plc
  claimSeq = claimSeq + 1
  witness = ''
  if cp~hasIndex('SPEAKER') then witness = cp['SPEAKER']
  else if rd~props~hasIndex(cpid) then if rd~props[cpid]~hasIndex('SPEAKER') then witness = rd~props[cpid]['SPEAKER']
  do pr over who~subWords
    if \ents~hasIndex(pr) then iterate
    if ents[pr]~name == '' then iterate
    if \cs~isa(ents[pr]~concept, nameC) then iterate
    cl = .Directory~new
    cl['SRC'] = csrc
    cl['TIER'] = ctier
    cl['BINDS'] = cbinds
    cl['PERSON'] = pr
    cl['PLACE'] = plc
    cl['POL'] = cp['POL']
    cl['LO'] = lo
    cl['HI'] = hi
    cl['PROP'] = cpid
    cl['WITNESS'] = witness
    cl['SELF'] = (pr == witness)
    cl['ALONE'] = (cp['COMPANY'] == 'none')
    cl['NOTE'] = cnote
    cl['CLAIM'] = claimSeq
    cl['TEXT'] = cpid': "'ctextp['TEXT']'"'
    claims~append(cl)
  end
  return

ground:
  use arg gsrc, gkind, gtier, gtarget, gunder, gbinds, gnote, gcl
  if \utt~hasIndex(gsrc) then do
    txt = 'testimony'
    if gtier == 'DOCUMENTARY' then txt = 'official record'
    utt[gsrc] = .Utterance~new(gsrc, txt)
  end
  gSeq = gSeq + 1
  gid = gsrc~left(1)||gSeq
  utt[gsrc]~assert(gkind, gtier, gtarget, gunder, gbinds, gnote, gid)
  gi = .Directory~new
  gi['SOURCE'] = gsrc
  gi['KIND'] = gkind
  gi['TIER'] = gtier
  gi['TARGET'] = gtarget
  gi['WITNESS'] = gcl['WITNESS']
  gi['BINDS'] = gbinds
  gi['CLAIMPLACE'] = gcl['PLACE']
  gi['CLAIM'] = gcl['CLAIM']
  gi['CLAIMPOL'] = gcl['POL']
  /* who and where the target proposition is about */
  do k over propOf~allIndexes
    if propOf[k] \== gtarget then iterate
    parse var k gp '/' gpl
    gi['PERSON'] = gp
    gi['PLACE'] = gpl
  end
  gInfo[gid] = gi
  return

undercut:
  use arg uu, ugid, upolicy, utext
  ugi = gInfo[ugid]
  if ugi['BINDS'] \== 'GENERAL' then return
  uu~assert('UNDERCUT', ugi['TIER'], ugi['TARGET'], ugid, 'GENERAL', '['upolicy']' utext, '')
  return

admitAll:
  do s over utt~allIndexes~sortWith(.CaselessComparator~new)
    net~admit(utt[s])
  end
  net~admit(pol)
  return

saidThere:
  use arg sq, spl
  do sc over claims
    if sc['BINDS'] \== 'GENERAL' then iterate
    if sc['PERSON'] == sq then if sc['PLACE'] == spl then if sc['POL'] == '+' then return .true
  end
  return .false

helps:
  use arg hg
  if hg['KIND'] == 'REBUT' then return wordpos(hg['PLACE'], crimePlaces) > 0
  if hg['KIND'] \== 'SUPPORT' then return .false
  if wordpos(hg['PLACE'], crimePlaces) > 0 then return .false
  if \win~hasIndex(hg['PLACE']) then return .false
  parse value win[hg['PLACE']] with hlo hhi
  do cx over crimePlaces~subWords
    if \win~hasIndex(cx) then iterate
    parse value win[cx] with clo chi
    if hhi >= clo then if hlo <= chi then return .true
  end
  return .false

related:
  use arg w, q
  if \ents~hasIndex(w) then return .false
  if \ents~hasIndex(q) then return .false
  if ents[q]~relOf == w then return .true
  if ents[w]~relOf == q then return .true
  return .false

relText:
  use arg w, q
  if ents[w]~relOf == q then return 'the witness is' nameOf(q)"'s" rz~noun(ents[w]~relation, .false)
  return nameOf(q) 'is the witness''s' rz~noun(ents[q]~relation, .false)

windowText:
  use arg wp
  if \win~hasIndex(wp) then return '(no time given)'
  parse value win[wp] with a b
  return clockText(a, b)

clockText:
  use arg a, b
  if a == '' then return '(no time given)'
  if a = b then return '(about' hm(a)')'
  return '('hm(a)'-'hm(b)')'

hm:
  use arg mins
  return (mins % 60)':'right(mins // 60, 2, '0')

placeList:
  use arg pls
  t = ''
  do x over pls~subWords
    t = t 'the' placeWord(x)
  end
  if t == '' then return 'none found'
  return t~strip

answerOf:
  use arg d
  if d['settled'] then return 'YES (settled)'
  if d['stance'] == 'CONTRA' then if d['assertible'] then return 'NO'
  if d['stance'] == 'PRO' then if d['assertible'] then return 'YES (supported, not settled)'
  return 'CANNOT TELL'

::requires 'reader.cls'
::requires 'realiser.cls'
::requires 'ReasonedThought.cls'
