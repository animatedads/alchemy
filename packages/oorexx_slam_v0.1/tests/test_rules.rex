/* One rule, two languages: the Federation Bank offline-cash rule in the ooRexx engine and the Java ATM.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch dir | FederationBankAtmGateway.cls | Java ATM src dir | ooRexx probe output | Java probe output
 * The probes (tests/rules/) run the real code of each side; run_tests.sh runs them first. This test
 * makes SLAM's predictions from the rules it read, then reads the probe results, then records each
 * one as a lesson on the GUARD -> RULE edge of that language.
 */
signal on syntax name onSyntax
parse arg work '|' engineCls '|' javaSrc '|' rexxOut '|' javaOut
checks = 0
call check work \= '' & engineCls \= '' & javaSrc \= '' & rexxOut \= '' & javaOut \= '', 'arguments: work | engineCls | javaSrc | rexxOut | javaOut'
rd = .SlamRuleReader~new

say '== 1. the ooRexx bank: validateAdvice read as rules'
text = charin(engineCls, 1, chars(engineCls)); call stream engineCls, 'C', 'CLOSE'
va = .nil
do u over .SlamUnitSplitter~new~split(text)
  if u~selector == 'VALIDATEADVICE' then va = u
end
rRules = rd~rexxUnit(va, engineCls)
call check rRules~items = 15, 'validateAdvice: 15 rules from 13 guards (got' rRules~items || ')'
st = findKey(rRules, 'EQ K:status S:ACTIVE')
call check st \== .nil & st~line = 262 & st~stop == 'REJECT', 'if rec["status"] <> "ACTIVE" then return ...failure  ->  MUST EQ K:status S:ACTIVE, REJECT'
cu = findKey(rRules, 'EQ K:currency V')
call check cu \== .nil & cu~flags == 'R^U' & cu~names == 'CURRENCYARG', 'currency: compared after ~upper on the presented value (R^U)'
am = findKey(rRules, 'GE K:maxAmountMinor V')
call check am \== .nil & findKey(rRules, 'GT V N:0') \== .nil, 'amount + 0 <= 0 | amount + 0 > rec["maxAmountMinor"] + 0  ->  two rules: GT V N:0, GE K:maxAmountMinor V'
se = findKey(rRules, 'EQ K:sessionId V')
call check se \== .nil & se~when~pos('NE K:sessionId S:') > 0, 'the session check holds only when the authority has a session (an IF around the guard)'
nt = findKey(rRules, 'NOTALL(EQ K:settlementIdempotencyKey V; EQ K:physicalTransactionId V)')
call check nt \== .nil & nt~stop == 'RETURN', 'a stop on (a & b) is one NOTALL rule; the replay answer is a RETURN, not a REJECT'

say '== 2. the Java ATM: keyed readers found by what they do'
atmFile = javaSrc || '/main/java/com/federationbank/atm/AtmService.java'
text = charin(atmFile, 1, chars(atmFile)); call stream atmFile, 'C', 'CLOSE'
units = .SlamJavaSplitter~new~split(text)
readers = rd~findReaders(units)
call check readers~items = 2 & readers~hasIndex('s') & readers~hasIndex('n'), 'keyed readers in AtmService: s and n (take a map and a key, read the map with the key)'
wo = .nil
do u over units
  if u~selector == 'withdrawOffline' then wo = u
end
jRules = rd~javaUnit(wo, atmFile)
call check findKey(jRules, 'EQ K:status S:ACTIVE')~stop == 'SKIP', '!"ACTIVE".equals(s(d,"status")) ... continue  ->  MUST EQ K:status S:ACTIVE, SKIP (this authority is not used)'
ex = findKey(jRules, 'GT K:expiresAt NOW')
call check ex \== .nil & ex~line = 316, 'expiry = Instant.parse(s(d,"expiresAt")); if (!Instant.now().isBefore(expiry)) continue  ->  MUST GT K:expiresAt NOW'
call check findKey(jRules, 'NE V NIL') \== .nil, 'auth is assigned twice, so it is not read through: if (auth == null) -> NE V NIL'

say '== 3. SLAM finds the Java counterparts itself'
call SysFileTree javaSrc || '/*.java', 'f.', 'FSO'
all = .array~new
do i = 1 to f.0
  text = charin(f.i, 1, chars(f.i)); call stream f.i, 'C', 'CLOSE'
  us = .SlamJavaSplitter~new~split(text)
  rd~findReaders(us)
  do u over us
    jr = rd~javaUnit(u, f.i)
    if jr~items > 0 then all~append(.array~of(u, jr, .SlamRuleReader~similarity(rRules, jr)))
  end
end
first = best(all); second = best(all)
say '      of' all~items + 2 'Java units with rules:' first[1]~selector format(first[3], 1, 3) ',' second[1]~selector format(second[3], 1, 3)
call check first[1]~selector == 'requestOfflineAllowance' & second[1]~selector == 'withdrawOffline', 'closest: requestOfflineAllowance (checks the authority it is given) and withdrawOffline (checks it before cash)'
shared = .array~new
do r over rRules
  if findKey(jRules, r~key) \== .nil then shared~append(r~key)
end
call check shared~items = 8, '8 rules are the same in validateAdvice (ooRexx) and withdrawOffline (Java):' shared~makeString('L', ' | ')
callers = .array~new
do u over units
  t = u~tokens
  do k = 1 to t~items - 1
    if t[k]~text == 'withdrawOffline' then if t[k + 1]~text == '(' then if u~selector \== 'withdrawOffline' then callers~append(.array~of(u, t[k]~line))
  end
end
call check callers~items = 1 & callers[1][1]~selector == 'withdraw', 'withdrawOffline has one caller: withdraw'
zeroRule = .nil
do r over rd~javaUnit(callers[1][1], atmFile)
  if r~key == 'GT V N:0' then if r~line < callers[1][2] then zeroRule = r
end
call check zeroRule \== .nil & zeroRule~line = 153, 'GT V N:0 is not missing on the Java side: withdraw checks it at line 153, before the call at line' callers[1][2]

say '== 4. RULE nodes: the same node from both languages'
db = work || '/rules.db'
call SysFileDelete db
store = .SlamStore~new(db)
call ingest store, engineCls, 'REXX'
do i = 1 to f.0
  call ingest store, f.i, 'JAVA'
end
store~begin
linked = 0
do key over shared
  a = .SlamRuleNodes~link(store, findKey(rRules, key))
  b = .SlamRuleNodes~link(store, findKey(jRules, key))
  if a \== .nil then if b \== .nil then if a[2] = b[2] then if a[1] \= b[1] then linked += 1
end
zl = .SlamRuleNodes~link(store, zeroRule)
store~commit
call check linked = 8, 'each shared rule is one RULE node with a made edge from an ooRexx GUARD and from a Java GUARD (8 of 8)'
ruleEdges = store~scalar("SELECT count(*) AS n FROM edge e JOIN shape s ON s.id = e.to_id WHERE s.kind = 'RULE' AND e.freq = 0")
call check ruleEdges = 17, 'made edges into RULE nodes: 17 (8 from 5 ooRexx GUARDs, since the terminal, customer and account guards are one node x3; 9 from 6 Java GUARDs, with withdraw''s amount check), all freq 0: no prior'

say '== 5. predict from the rules, then run the real code (cases SLAM chose from the differences)'
cases = .array~of(.array~of('MAX_EQUAL', 'GE K:maxAmountMinor V', 10000, 10000), .array~of('MAX_PLUS_ONE', 'GE K:maxAmountMinor V', 10000, 10001), .array~of('ZERO', 'GT V N:0', '', 0), .array~of('CURRENCY_LOWER', 'EQ K:currency V', 'GBP', 'gbp'))
predicted = .directory~new
do c over cases
  rr = findKey(rRules, c[2])
  jj = findKey(jRules, c[2])
  if jj == .nil then if c[2] == 'GT V N:0' then jj = zeroRule
  predicted['REXX' c[1]] = .array~of(okWord(rr~holds(c[3], c[4])), rr)
  predicted['JAVA' c[1]] = .array~of(okWord(jj~holds(c[3], c[4])), jj)
  say '      ' left(c[1], 15) 'ooRexx predicted' left(predicted['REXX' c[1]][1], 8) 'Java predicted' predicted['JAVA' c[1]][1]
end
call check predicted['REXX CURRENCY_LOWER'][1] == 'ok' & predicted['JAVA CURRENCY_LOWER'][1] == 'refused', 'before any run, SLAM predicts the sides differ on "gbp": the ooRexx rule has ^U, the Java rule has none'
right = 0; lessons = 0
store~begin
do lang over .array~of('REXX', 'JAVA')
  outFile = rexxOut
  if lang == 'JAVA' then outFile = javaOut
  do while lines(outFile) > 0
    parse value linein(outFile) with tag name state code .
    if tag \== 'CASE' then iterate
    p = predicted[lang name]
    ok = (p[1] == state)
    if ok then right += 1
    nodes = .SlamRuleNodes~link(store, p[2])
    store~lesson(nodes[1], nodes[2], ok, 'will be' p[1], lang 'run:' state code, name)
    lessons += 1
    say '      ' left(lang, 5) left(name, 15) 'predicted' left(p[1], 8) 'ran' left(state, 8) code
  end
  call stream outFile, 'C', 'CLOSE'
end
store~commit
call check lessons = 8 & right = 8, 'all 8 predictions match the real runs (4 cases x 2 languages), each kept as a lesson'
cur = .SlamRuleNodes~ruleNode(store, cu)
tested = store~scalar("SELECT count(*) AS n FROM weight WHERE to_id = ? AND trials > 0 AND passes = trials", store~binds(cur))
call check tested = 2, 'RULE: EQ K:currency V is now reached by a TESTED edge from each language (both predictions true)'
store~close

say '== 6. late advice: the Java test bank and the ooRexx bank read differently'
demoFile = javaSrc || '/main/java/com/federationbank/atm/bank/DemoBankNetwork.java'
text = charin(demoFile, 1, chars(demoFile)); call stream demoFile, 'C', 'CLOSE'
dus = .SlamJavaSplitter~new~split(text)
rd~findReaders(dus)
demoRule = .nil
do u over dus
  if u~selector \== 'offlineWithdrawalAdvice' then iterate
  do r over rd~javaUnit(u, demoFile)
    if r~key == 'LE NOW V' then if r~names == 'expiresAt' then demoRule = r
  end
end
call check demoRule \== .nil & demoRule~stop == 'REJECT' & demoRule~line = 215, 'DemoBankNetwork (Java) line 215: MUST LE NOW V [expiresAt], REJECT: advice after expiry is refused'
nowRules = 0
do r over rRules
  if r~must~pos('NOW') > 0 then nowRules += 1
end
call check nowRules = 0, 'validateAdvice (ooRexx) has no rule on the time the advice arrives'
late = .directory~new
do while lines(rexxOut) > 0
  parse value linein(rexxOut) with tag name state code .
  if tag == 'LATE' then late[name] = state code
end
call stream rexxOut, 'C', 'CLOSE'
call check late['LATE_DISPENSED_INSIDE'] == 'ok ATM_OFFLINE_DELAYED_EVIDENCE_ACCEPTED', 'run: the ooRexx bank accepts advice 2 hours late when the cash went out inside the authority (' || late['LATE_DISPENSED_INSIDE'] || ')'
call check late['LATE_DISPENSED_OUTSIDE'] == 'refused ATM_OFFLINE_DISPENSE_OUTSIDE_AUTHORITY', 'run: and refuses it when the cash went out after expiry (' || late['LATE_DISPENSED_OUTSIDE'] || ')'

say 'RULES TEST: PASS (' || checks || ' checks)'
exit 0

okWord: procedure
  use arg h
  if h == .true then return 'ok'
  if h == .false then return 'refused'
  return 'unknown'

findKey: procedure
  use arg rules, key
  do r over rules
    if r~key == key then return r
  end
  return .nil

best: procedure
  use arg all
  top = 0; topScore = -1
  do k = 1 to all~items
    if all[k][3] > topScore then do; top = k; topScore = all[k][3]; end
  end
  e = all[top]
  all~delete(top)
  return e

ingest: procedure
  use arg store, file, lang
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  seg = .SlamLanguages~segmenter(lang)
  store~begin
  do u over .SlamLanguages~splitter(lang)~split(text)
    segs = seg~segmentUnit(u)
    if segs~items > 0 then uid = store~ingestUnit(file, u, segs)
  end
  store~commit
  return

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamRules.cls'
::requires 'SlamStore.cls'
