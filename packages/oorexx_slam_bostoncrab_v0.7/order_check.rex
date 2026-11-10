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

o = .Stream~new(dir'/out/orders.txt')~~open('write replace')
call out 'Orders and messages:' rd~orders~items
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
    if c \== .nil then if c['E']['FEATS']['kind'] == 'def' then do
      np = rd~parseNP(toks, k)
      if np \== .nil then if np['KIND'] == 'def' then do
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
  /* what the reader could not read was not checked */
  p = rd~parseClause(toks, 'order')
  if p == .nil then do
    call out '  NOT CHECKED  the reader could not parse this sentence; references above were checked, its meaning was not'
    unchecked = 1
  end
  else if p['NOTE'] \== '' then do
    call out '  NOT CHECKED  'p['NOTE']
    unchecked = 1
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
  nm = ents[nid]~name
  return nm~left(1)~upper||nm~substr(2)

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
    if \ok then if kinds~hasIndex(e) then do kc over kinds[e]~subWords
      if cs~isa(kc, core['CONCEPT']) then ok = 1
    end
    if \ok then iterate
    if \rd~attrsMatch(ents[e], core['ATTRS']) then iterate
    found = found e
  end
  return found~strip

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
  use arg set
  t = ''
  do e over set~subWords
    if t \== '' then t = t 'and'
    t = t describe(e)
  end
  return t~strip

checkRef:
  use arg np, from, to
  phrase = '"the' rz~noun(np['CORE']['CONCEPT'], np['CORE']['PLURAL'] == 1)'"'
  w = preferCommand(candidates(np, from), to)
  r = preferCommand(candidates(np, to), to)
  if words(w) = 0 then if words(r) = 0 then return 'NO REFERENT  'phrase': neither' nameOf(from) 'nor' nameOf(to) 'can see anything it could mean'
  if words(r) = 0 then return 'NOT VISIBLE  'phrase': for' nameOf(from) 'it is' listOf(w)';' nameOf(to) 'can see nothing it could mean'
  if words(r) > 1 then return 'AMBIGUOUS  'phrase':' nameOf(to) 'can see' words(r) 'things it could mean:' listOf(r)
  if words(w) > 1 then return 'WRITER AMBIGUOUS  'phrase': it fits' words(w) 'things' nameOf(from) 'can see ('listOf(w)');' nameOf(to) 'can see only' listOf(r)', so he will take it as that'
  if words(w) = 0 then return 'CLEAR  'phrase': for' nameOf(to) 'it is' listOf(r) '(' || nameOf(from) 'cannot see it)'
  if w \== r then return 'MEANS DIFFERENT THINGS  'phrase':' nameOf(from) 'means' listOf(w)', but' nameOf(to) 'will take' listOf(r)
  return 'CLEAR  'phrase': both mean' listOf(r)

::requires 'reader.cls'
::requires 'realiser.cls'
