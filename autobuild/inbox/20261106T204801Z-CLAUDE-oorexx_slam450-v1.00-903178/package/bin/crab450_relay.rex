/* crab450_relay.rex - SLAM 450 v0.99 (Boston Crab v0.19): what each recipient will do with an order.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * Reads Boston Crab's machine report, out/orders.words (v0.14+): one fact a
 * line, fields split by |, "--" lines are comments:
 *   order|n|from|to|words   part|n|i|verb|action|how|words
 *   ref|n|i|verdict|words|writer|reader   end|n|verdict   fail|n|reason
 * Boston Crab is the one judge of what words mean: this program never
 * resolves a reference itself. A grid reference ("E -446 N -384") is a ref
 * whose writer is "grid E <east> N <north>" (Boston Crab v0.15); before
 * v0.15 it was read here from the part's words, and that stays as a
 * fallback when a part has no grid ref line. Actions and "how" are concept names,
 * the same for English and Ukrainian, so nothing here reads either language.
 * The nearest name for an UNKNOWN NAME is taken from out/orders.txt, the
 * only place Boston Crab gives it.
 * Usage: rexx crab450_relay.rex dir   (any Rexx; it needs no Boston Crab class)
 * Reads bind.words, places.words, out/orders.words, out/orders.txt; writes
 * out/relay.txt, one line per step:
 *   n|part|from|to|verdict|action|place|dir|reading|sentence
 * action: ORBIT, SEARCH, HOLD, RETURN, MOVE or NONE. place: a SLAM place
 * key, grid:x:y, here (where the craft is), UNABLE or ''. dir: CW, CCW or ''.
 * One step per place a part names: a set ("the north pylons", CLEAR with two
 * things) is visited thing by thing. The recipient acts on its own reading at
 * once (Tom Dyer: no time for chatter):
 *   CLEAR, WRITER AMBIGUOUS, MEANS DIFFERENT THINGS -> what the reader takes
 *   AMBIGUOUS              -> the nearest of what the reader could mean
 *   UNKNOWN NAME           -> the nearest name, said so
 *   NO REFERENT, NOT VISIBLE -> UNABLE; the craft keeps its task
 * An order Boston Crab failed on (fail|n|reason, v0.15) gets one line,
 * verdict NOT CHECKED, action NONE, place UNABLE: SLAM does not act on it,
 * and Control is told which order it was. The other orders run as normal.
 * v0.97 (Boston Crab v0.16): "not" in a part's how field ("не знижуйтесь",
 * "do not descend") makes the part a prohibition: action DONT, and the
 * reading starts "not <ACTION>:". SLAM never flies a DONT step; the craft
 * notes it, as it does AVOID.
 * v0.98 (Boston Crab v0.18): "if" in the how field ("якщо ціль знайдено ...,
 * повертайтеся") is a conditional order: action IF, reading "if <verb>:".
 * SLAM cannot evaluate conditions, so it never flies an IF step; Control is
 * told the order was conditional. "not" with no verb at all ("Alpha, ні.")
 * is no order: action NONE. tone| lines are not orders; the race shows them
 * to Control.
 * v0.98 (Boston Crab v0.19): relay lines carry an 11th field, the actions
 * the order says to do without ("without stop": an orbit or search that
 * never stops on its own). A craft named in an order is its object, not a
 * place, except for AVOID. */
parse arg dir .
/* SLAM's action table: concept names (the part before ~), never order words */
actTab = .array~of('AVOID avoid shun evade', 'RETURN return withdraw retreat', 'HOLD hold keep wait hover stay loiter stop halt', ,
  'ORBIT orbit orb circle', 'SEARCH search inspect inspection check sweep scan patrol explore look watch observe monitor zone survey reconnoitre reconnoiter', ,
  'MOVE fly go move head proceed advance travel')
said = .StringTable~new
bs = .Stream~new(dir'/bind.words')~~open('read')
do while bs~lines > 0
  ln = bs~linein~strip
  if ln = '' | ln~left(2) = '--' then iterate
  parse var ln 'bind' place phrase
  said[place] = norm(phrase)
end
bs~close
xyz = .StringTable~new
ps = .Stream~new(dir'/places.words')~~open('read')
do while ps~lines > 0
  parse value ps~linein with 'place' k x y z .
  if k \== '' then xyz[k] = x y z
end
ps~close
/* the nearest names Boston Crab gives for unknown names, in report order */
nearestNames = .array~new
ts = .Stream~new(dir'/out/orders.txt')~~open('read')
do while ts~lines > 0
  ln = ts~linein
  if pos('UNKNOWN NAME', ln) = 0 then iterate
  parse var ln . 'nearest:' nm
  nearestNames~append(nm~strip)
end
ts~close
/* the machine report */
orders = .array~new; parts = .directory~new; refs = .directory~new; ends = .directory~new; fails = .directory~new
ws = .Stream~new(dir'/out/orders.words')~~open('read')
do while ws~lines > 0
  ln = ws~linein
  if ln~strip == '' | ln~left(2) == '--' then iterate
  f = ln~makeArray('|')
  select
    when f[1] == 'order' then orders~append(f)
    when f[1] == 'part' then do; k = f[2]; if \parts~hasIndex(k) then parts[k] = .array~new; parts[k]~append(f); end
    when f[1] == 'ref' then do; k = f[2]'.'f[3]; if \refs~hasIndex(k) then refs[k] = .array~new; refs[k]~append(f); end
    when f[1] == 'end' then ends[f[2]] = f[3]
    when f[1] == 'fail' then fails[f[2]] = field(f, 3)
    otherwise nop
  end
end
ws~close
unk = 0
o = .Stream~new(dir'/out/relay.txt')~~open('write replace')
do of over orders
  n = of[2]; from = of[3]; to = of[4]; sentence = field(of, 5)
  verdict = '?'; if ends~hasIndex(n) then verdict = ends[n]
  if fails~hasIndex(n) then do
    o~lineout(n'|1|'from'|'to'|NOT CHECKED (Boston Crab failed on this order)|NONE|UNABLE||Boston Crab failed on this order ('fails[n]'); not checked, not acted on|'sentence)
    iterate
  end
  plist = .array~new; if parts~hasIndex(n) then plist = parts[n]
  if plist~items = 0 then plist = .array~of(.array~of('part', n, 1, '-', '-', '-', sentence))
  lastPlace = ''
  do pf over plist
    i = pf[3]; action = actionOf(pf[5], pf[4]); rot = rotOf(pf[6])
    negated = isNot(pf[6]); conditional = isWord(pf[6], 'if')
    wo = withoutOf(pf[6])   /* v0.98: "without stop" (кружляйте, не зупиняючись) */
    /* a bare "no" ("Alpha, ні."): "not" with no verb is not an order */
    bareNo = 0
    if negated & \conditional & pf[4] == '-' & pf[5] == '-' then do; negated = 0; bareNo = 1; end
    steps = .array~new; grids = .array~new
    rl = .array~new; if refs~hasIndex(n'.'i) then rl = refs[n'.'i]
    do rf over rl
      v = rf[4]; words = rf[5]; reader = field(rf, 7)
      keys = ''
      do d over reader~makeArray(';')
        k = keyOf(d)
        if k \== '' then keys = keys k
      end
      keys = keys~strip
      /* v0.98 (Boston Crab v0.19 checks a command's object): a craft named in
         an order ("відведіть дрон", withdraw the drone) is what the order acts
         on, not a place to fly to; only AVOID keeps craft (the hostile drones) */
      if action \== 'AVOID' & keys \== '' then do
        kk = ''
        do k over keys~subWords; if wordpos(k, 'control alpha bravo charlie delta echo foxtrot') = 0 then kk = kk k; end
        if kk == '' then iterate
        keys = kk~strip
      end
      select
        when field(rf, 6)~left(5) == 'grid ' then do
          /* Boston Crab v0.15: a grid reference, CLEAR, the same place for everyone */
          parse value field(rf, 6) with 'grid' . gx . gy .
          if datatype(gx, 'N') & datatype(gy, 'N') then grids~append(.array~of('grid:'gx':'gy, 'grid reference E' gx 'N' gy))
          else steps~append(.array~of('UNABLE', '"'words'": a grid reference SLAM cannot read'))
        end
        when v == 'UNKNOWN NAME' then do
          unk = unk + 1; nk = ''
          if nearestNames~items >= unk then nk = keyOf(nearestNames[unk])
          if nk \== '' then steps~append(.array~of(nk, '"'words'" is not a known name; took the nearest name,' said[nk]))
          else steps~append(.array~of('UNABLE', '"'words'": no such name'))
        end
        when v~word(1) == 'NO' | v == 'NOT VISIBLE' then steps~append(.array~of('UNABLE', '"'words'": nothing it can identify ('v~lower')'))
        when v == 'AMBIGUOUS' then do
          k = nearest(keys, to)
          if k \== '' then steps~append(.array~of(k, '"'words'" fits' words(keys) 'it can identify; took the nearest,' said[k]))
        end
        when keys == '' then nop          /* a thing SLAM has no place for (Sydney Harbour) */
        when words(keys) > 1 then do k over keys~subWords
          steps~append(.array~of(k, '"'words'" names' words(keys)':' said[k]))
        end
        otherwise do
          r = '"'words'" taken as' said[keys]
          if v == 'WRITER AMBIGUOUS' then r = r '(the writer could mean more than one)'
          if v == 'MEANS DIFFERENT THINGS' then r = r '(not what the writer means)'
          steps~append(.array~of(keys, r))
        end
      end
    end
    /* only UNABLE steps alongside a resolved one are dropped */
    good = .array~new
    do st over steps; if st[1] \== 'UNABLE' then good~append(st); end
    if good~items > 0 then steps = good
    else if steps~items > 1 then steps = .array~of(steps[1])
    /* a grid reference says where when nothing else in the part does
       (with a name, as in "Garnet, E 114 N 92", it only repeats the name) */
    if grids~items > 0 then do
      good = .array~new
      /* v0.98: the Field only contains a grid reference ("search the area at
         E -446 N -384": Boston Crab v0.18 reads "the area" as the Field) */
      do st over steps; if st[1] \== 'UNABLE' & st[1] \== 'field' then good~append(st); end
      steps = good
      if steps~items = 0 then steps = grids
    end
    g = ''; if grids~items = 0 then g = gridRef(pf[7])
    if g \== '' then do
      parse var g 'grid:' gx ':' gy
      good = .array~new
      /* v0.98: the Field only contains a grid reference ("search the area at
         E -446 N -384": Boston Crab v0.18 reads "the area" as the Field) */
      do st over steps; if st[1] \== 'UNABLE' & st[1] \== 'field' then good~append(st); end
      steps = good
      if steps~items = 0 then steps~append(.array~of(g, 'grid reference E' gx 'N' gy))
    end
    /* last resort: a map name said word for word that the report has no
       line for; the reading says Boston Crab did not check it */
    if steps~items = 0 then do
      txt = ' 'pf[7]~lower~changeStr(',', ' ')~changeStr('.', ' ')~space' '
      best = ''
      do k over said~allIndexes
        /* v0.97: Boston Crab v0.17 checks the base itself ("до бази", "return to base") */
        if wordpos(k, 'control alpha bravo charlie delta echo foxtrot base') > 0 then iterate
        if pos(' 'said[k]' ', txt) = 0 then iterate
        if best == '' then best = k
        else if words(said[k]) > words(said[best]) then best = k
      end
      if best \== '' then steps~append(.array~of(best, '"'said[best]'" is a map name (not checked by Boston Crab)'))
    end
    /* v0.96: one place named twice in a part ("летіть до Opera House, потім
       ... між Opera House") is one step */
    if steps~items > 1 then do
      good = .array~new; seen = ''
      do st over steps
        if st[1] \== 'UNABLE' & wordpos(st[1], seen) > 0 then iterate
        good~append(st); seen = seen st[1]
      end
      steps = good
    end
    /* v0.96: the Field holds every place; named with others ("the west part
       of the field, starting from Walsh Bay wharves, then Observatory Hill")
       it says where they are, and is not a stop of its own */
    if steps~items > 1 then do
      good = .array~new
      do st over steps; if st[1] \== 'field' then good~append(st); end
      if good~items > 0 then steps = good
    end
    /* v0.96: hold or withdraw to a set ("the north pylons") stays at one:
       the nearest; a craft that stays cannot go on to the next */
    if (action == 'HOLD' | action == 'RETURN') & steps~items > 1 then do
      ks = ''
      do st over steps; if st[1] \== 'UNABLE' & st[1]~left(5) \== 'grid:' then ks = ks st[1]; end
      k = nearest(ks~strip, to)
      if k \== '' then steps = .array~of(.array~of(k, 'one of' words(ks) 'to stay at; took the nearest,' said[k]))
    end
    /* a part that names places but no act: an area given to the craft, and
       searching is its task (Charlie, "ваша зона - Circular Quay";
       "працюйте від східного причалу до західного") */
    /* only with no verb, or a verb that just says "work": an unknown verb
       is never turned into a visit ("уникайте пілонів", avoid the pylons,
       must not send the craft to them) */
    vb = pf[4]; parse var vb vb '~' .
    /* and only when Boston Crab read every word: an unread word may be the
       verb ("уникайте", avoid, is not in its dictionary yet) */
    if action == 'NONE' & steps~items > 0 & wordpos(vb~lower, '- work operate') > 0 & pos('NOT', verdict) = 0 then
      if steps[1][1] \== 'UNABLE' & steps[1][1] \== '' then action = 'SEARCH'
    /* an act with no place of its own works where the last part sent it */
    if steps~items = 0 & action \== 'NONE' & \negated & \conditional & lastPlace \== '' then steps~append(.array~of(lastPlace, 'the same place,' said[lastPlace]))
    /* v0.97: "чекайте там" (wait there) with nowhere named: hold where it is */
    if steps~items = 0 & action == 'HOLD' & \negated & \conditional then steps~append(.array~of('here', 'hold where it is'))
    if steps~items = 0 & action == 'RETURN' & \negated & \conditional then steps~append(.array~of('base', 'return: the base'))
    if steps~items = 0 then steps~append(.array~of('', 'no place named'))
    /* v0.97: a prohibition is never a step to fly: action DONT */
    if negated | conditional then do st over steps
      nv = '-'; do c over .array~of(pf[5], pf[4]); parse var c b '~' .; if b \== '-' & b \== '' then do; nv = b~lower; leave; end; end
      if conditional then st[2] = 'if' nv':' st[2]
      else st[2] = 'not' nv':' st[2]
    end
    if bareNo then do st over steps; st[2] = '"not" with no verb (a bare no): no order'; end
    do st over steps
      if st[1] \== '' & st[1] \== 'UNABLE' & st[1]~left(5) \== 'grid:' & \negated & \conditional then lastPlace = st[1]
      act = action; if negated then act = 'DONT'; if conditional then act = 'IF'
      rdg = st[2]; if action == 'NONE' & \negated & \conditional & \bareNo then rdg = rdg'; no action it knows'
      o~lineout(n'|'i'|'from'|'to'|'verdict'|'act'|'st[1]'|'rot'|'rdg'|'pf[7]'|'wo)
    end
  end
end
o~close
exit 0

/* ----------------------------------------------------------------------- */
field: procedure
  use arg f, k
  if f~items < k then return ''
  return f[k]

norm: procedure
  parse arg t
  t = t~strip~lower
  if t~word(1) == 'the' then t = t~subword(2)
  return t~space

keyOf: procedure expose said
  parse arg d
  d = norm(d)
  if d == '' then return ''
  do k over said~allIndexes
    if said[k] == d then return k
  end
  return ''

/* the SLAM action for a part: its action concept, else its verb concept */
actionOf: procedure expose actTab
  parse arg act, verb
  do c over .array~of(act, verb)
    parse var c base '~' .
    base = base~lower
    if base == '-' | base == '' then iterate
    do row over actTab
      if wordpos(base, row~subWords~section(2)~makeString('L', ' ')) > 0 then return row~word(1)
    end
  end
  return 'NONE'

withoutOf: procedure
  /* v0.98 (Boston Crab v0.19): the actions after "without" in the how field,
     "without stop" -> stop; "without search~01318273-v" -> search */
  parse arg how
  ws = how~translate('  ', ';,')~subWords; out = ''
  do i = 1 to ws~items - 1
    if ws[i]~lower == 'without' then do; parse value ws[i+1] with b '~' .; out = out b~lower; end
  end
  return out~strip

isWord: procedure
  /* is w one of the how field's words (Boston Crab v0.17+: space-separated) */
  parse arg how, w
  do x over how~translate('  ', ';,')~subWords
    parse var x base '~' .
    if base~lower == w then return 1
  end
  return 0

isNot: procedure
  parse arg how
  do w over how~translate('  ', ';,')~subWords
    parse var w base '~' .
    if base~lower == 'not' then return 1
  end
  return 0

rotOf: procedure
  /* v0.97: the how field may hold several words ("not clockwise~00255849-r") */
  parse arg how
  do w over how~translate('  ', ';,')~subWords
    parse var w base '~' .
    base = base~lower
    if wordpos(base, 'anticlockwise counterclockwise') > 0 then return 'CCW'
    if base == 'clockwise' then return 'CW'
  end
  return ''

nearest: procedure expose xyz
  use arg set, who
  if set == '' then return ''
  me = who~lower
  if \xyz~hasIndex(me) then return set~word(1)
  parse value xyz[me] with mx my .
  best = ''; bd = 1e20
  do k over set~subWords
    if \xyz~hasIndex(k) then iterate
    parse value xyz[k] with px py .
    dd = (px - mx)**2 + (py - my)**2
    if dd < bd then do; bd = dd; best = k; end
  end
  return best

gridRef: procedure
  parse arg gt
  gt = gt~lower~changeStr(',', ' ')
  ge = wordpos('e', gt)
  do while ge > 0
    gx = gt~word(ge + 1); gn = gt~word(ge + 2); gy = gt~word(ge + 3)
    if datatype(gx, 'N') & gn == 'n' & datatype(gy, 'N') then return 'grid:'gx':'gy
    ge = wordpos('e', gt, ge + 1)
  end
  return ''
