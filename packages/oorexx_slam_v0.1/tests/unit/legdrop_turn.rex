/* Leg Drop, steps four and five: keep or undo one change to one case rule, by rule, and store the turn.
 * Architecture: Tom Dyer (Leg Drop: proposed by the rx2cpp lane, Claude (Opus 5.5)). Code: Claude (Opus 5.5), 2026-10-30.
 * Args: db | rule | change | estate=before score file=after score file [; estate=before=after ...]
 *   score files: from rule_score.rex
 * The rule's score is the mutants only it catches, for each case it writes (what it adds for what it costs).
 * The change is kept when, on every estate:
 *   1. the rule's score is more;
 *   2. no other rule catches fewer mutants alone than before;
 *   3. the suite catches no fewer mutants than before (killed, plus the ones that run past the time limit,
 *      as in run_mutants.sh).
 * Otherwise it is undone. Each estate's line is stored in rule_turn with the decision.
 */
parse arg db '|' rule '|' change '|' estates
rule = rule~strip~upper
keep = .true
lines = .array~new
do e over estates~makeArray(';')
  parse var e estate '=' bf '=' af
  b = readScore(bf~strip); a = readScore(af~strip)
  why = .array~new
  okE = .true
  sb = ratio(b, rule); sa = ratio(a, rule)
  if \(sa > sb) then do; okE = .false; why~append(rule 'score not more:' sb '->' sa); end
  do k over b~allIndexes~sort
    if k~left(5) \== 'ONLY ' then iterate
    r = k~substr(6)
    if r == rule then iterate
    if num(a, k) < num(b, k) then do; okE = .false; why~append(r 'catches fewer alone:' num(b, k) '->' num(a, k)); end
  end
  cb = num(b, 'KILLED') + num(b, 'TIMEOUT'); ca = num(a, 'KILLED') + num(a, 'TIMEOUT')
  if ca < cb then do; okE = .false; why~append('the suite catches fewer:' cb '->' ca); end
  if why~items == 0 then why~append('every check holds')
  if \okE then keep = .false
  before = 'cases' num(b, 'CASES' rule) 'only' num(b, 'ONLY' rule) 'score' sb 'suite' cb '(timeouts' num(b, 'TIMEOUT') || ')'
  after = 'cases' num(a, 'CASES' rule) 'only' num(a, 'ONLY' rule) 'score' sa 'suite' ca '(timeouts' num(a, 'TIMEOUT') || ')'
  lines~append(.array~of(estate~strip, before, after, okE, why~makeString('L', '; ')))
end
store = .SlamStore~new(db)
store~begin
do l over lines
  say l[1]~left(10) 'before:' l[2]
  say ''~left(10) 'after: ' l[3]
  say ''~left(10) (l[4])~?('holds', 'fails') || ':' l[5]
  store~q('INSERT INTO rule_turn (rule, change, estate, before, after, kept, why) VALUES (?, ?, ?, ?, ?, ?, ?)', store~binds(rule, change, l[1], l[2], l[3], keep~?(1, 0), l[5]))
end
store~commit
store~close
say 'TURN' rule (keep)~?('KEPT', 'UNDONE') || ':' change
exit (keep)~?(0, 3)

readScore: procedure
  use arg f
  d = .directory~new
  do while lines(f) > 0
    ln = linein(f)
    if ln~word(1) == 'RULE' then do
      parse var ln . r . cases . catch . only . idle .
      d['CASES' r] = cases; d['CATCH' r] = catch; d['ONLY' r] = only; d['IDLE' r] = idle
    end
    else d[ln~word(1)] = ln~word(2)
  end
  call stream f, 'C', 'CLOSE'
  return d

num: procedure
  use arg d, k
  v = d[k]
  if v~isNil then return 0
  return v

ratio: procedure
  use arg d, r
  c = num(d, 'CASES' r)
  if c = 0 then return 0
  return format(num(d, 'ONLY' r) / c, , 4)

::requires 'SlamStore.cls'
