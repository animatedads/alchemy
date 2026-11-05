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
call out 'Orders and messages:' rd~orders~items
if mapUsed > 0 then call out 'Map:' mapSource',' mapUsed 'sight lines, bound to the situation'
open = .StringTable~new           /* sender -> the open questions in his last message */
do od over rd~orders
  toks = od['TOKS']
  from = od['FROM']
  to = od['TO']
  text = rd~join(toks, 1, toks~items)
  call out ''
  call out nameOf(from) '->' nameOf(to)':' text
  flags = 0
  unchecked = 0
  /* a bare acknowledgement */
  ackOnly = 1
  do k = 1 to toks~items
    if verify(toks[k], '.,!?') = 0 then iterate
    c = lex~find(toks, k, 'formula')
    if c == .nil then ackOnly = 0
    else if c['E']['FEATS']['ack'] \== 'yes' then ackOnly = 0
  end
  if ackOnly then do
    if open~hasIndex(to) then if open[to] \== '' then do
      call out '  ACK DOES NOT RESOLVE  "'text'" answers a message with an open question ('open[to]~strip'); it does not say which reading was taken'
      flags = flags + 1
    end
    if flags = 0 then call out '  CLEAR'
    else call out '  REQUIRES CLARIFICATION'
    open[from] = ''
    iterate
  end
  qs = ''
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
        res = checkRef(np, from, to)
        call out '  'res
        if res~word(1) \== 'CLEAR' then do
          flags = flags + 1
          qs = qs '"'rd~join(toks, k, np['NEXT'] - 1)'"'
        end
        k = np['NEXT']
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
          call out '  UNKNOWN NAME  "'rd~join(toks, k, np['NEXT'] - 1)'": the situation has no place or person of that name'
          flags = flags + 1
          qs = qs '"'rd~join(toks, k, np['NEXT'] - 1)'"'
        end
        if e \== '' then if e \== from then if e \== to then do
          res = checkName(e, from, to)
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
  do part over parts
    p = rd~parseClause(part, 'order')
    if p == .nil then do
      call out '  NOT CHECKED  the reader could not parse "'rd~join(part, 1, part~items)'"; its references were checked, its meaning was not'
      unchecked = 1
    end
    else if p['NOTE'] \== '' then do
      call out '  NOT CHECKED  'p['NOTE']
      unchecked = 1
    end
  end
  open[from] = qs
  if flags > 0 then call out '  REQUIRES CLARIFICATION'
  else if unchecked then call out '  NOTHING FOUND, BUT NOT FULLY CHECKED'
  else call out '  CLEAR'
end
o~close
exit 0

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
    if ok then if core['PLURAL'] \== 1 then if ents[e]~plural == 1 then ok = 0
    if \ok then if kinds~hasIndex(e) then do kc over kinds[e]~subWords
      if cs~isa(kc, core['CONCEPT']) then ok = 1
    end
    if \ok then iterate
    if \nameModsMatch(e, core['ATTRS']) then iterate
    found = found e
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
  return rd~attrsMatch(ents[nmE], nmRest~strip)

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
  if np['WHERE'] \== '' then do
    phrase = phrase~left(phrase~length - 1) np['WHERETEXT']'"'
    w = placedAt(w, np['WHERE'])
    r = placedAt(r, np['WHERE'])
  end
  if words(w) = 0 then if words(r) = 0 then return 'NO REFERENT  'phrase': neither' nameOf(from) 'nor' nameOf(to) 'can see anything it could mean'
  if words(r) = 0 then return 'NOT VISIBLE  'phrase': for' nameOf(from) 'it is' listOf(w, from)';' nameOf(to) 'can see nothing it could mean'
  if words(r) > 1 then return 'AMBIGUOUS  'phrase':' nameOf(to) 'can see' words(r) 'things it could mean:' listOf(r, to)
  if words(w) > 1 then return 'WRITER AMBIGUOUS  'phrase': it fits' words(w) 'things' nameOf(from) 'can see ('listOf(w, from)');' nameOf(to) 'can see only' listOf(r, to)', so he will take it as that'
  if words(w) = 0 then return 'CLEAR  'phrase': for' nameOf(to) 'it is' listOf(r, to) '(' || nameOf(from) 'cannot see it)'
  if w \== r then return 'MEANS DIFFERENT THINGS  'phrase':' nameOf(from) 'means' listOf(w, from)', but' nameOf(to) 'will take' listOf(r, to)
  return 'CLEAR  'phrase': both mean' listOf(r, to)

::requires 'reader.cls'
::requires 'realiser.cls'
