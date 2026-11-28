/* truth.rex - lies, kept promises and CANNOT TELL, decided by Reasoned Thought.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Each case runs the real reading path (view, assessment, message reader,
   mind) on the framework's own rendered text. */
parse arg root
if root == '' then root = '.'
ck = .HeelTurnCheck~new('truth')
fx = .HeelTurnFixture~new(root'/tests/fixtures/spring1901_aus_press.txt')
vocab = .HeelTurnVocabulary~new(root'/data')

-- 1. a plain promise is TESTIMONY: assertible (SUPPORTED), not settled; the
--    mail header (PROVENANCE, MAIL_ENVELOPE) is INELIGIBLE for it
m = mindFor(fx, vocab, .array~of('1901S-R1-001|RUS|AUS|I will not move into GAL this turn.'), .array~new, .array~new)
e = findIn(m, 'RUS', 'NOMOVE', 'GAL')
ck~that(e \== .nil, '1: promise read into the ledger')
d = m~decisionFor(e)
ck~that(d['status'] == 'SUPPORTED', '1: promise alone is SUPPORTED (testimony), status' d['status'])
ck~that(\d['settled'], '1: a promise alone is not settled')
ck~that(d['ineligible']~items = 1, '1: the mail header is INELIGIBLE (binds who sent it, not that it is true)')
ck~that(m~relied~items = 1, '1: Heel Turn may plan on it')
memory = m~serialize~makeArray('0A'x)

-- 2. the published orders contradict it: a DOCUMENTARY rebuttal, a lie
m2 = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR - GAL'), memory, 'PRESS', 'FALL_MOVEMENT')
e = findIn(m2, 'RUS', 'NOMOVE', 'GAL')
d = m2~decisionFor(e)
ck~that(d['stance'] == 'CONTRA' & d['rebutTier'] = 3, '2: broken promise is CONTRA at DOCUMENTARY')
ck~that(m2~recentLies('RUS') = 1, '2: the lie is recorded')
ck~that(m2~trust['RUS'] < 0.5, '2: trust falls on a documentary verdict only')
ck~that(hasEvent(m2, 'LIE RUS BROKE_NOMOVE'), '2: LIE event')

-- 3. the published orders match it: SETTLED, trust rises
m3 = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR - UKR'), memory, 'PRESS', 'FALL_MOVEMENT')
d = m3~decisionFor(findIn(m3, 'RUS', 'NOMOVE', 'GAL'))
ck~that(d['settled'], '3: kept promise SETTLED at DOCUMENTARY')
ck~that(m3~trust['RUS'] > 0.5, '3: trust rises on a settled promise')
ck~that(m3~recentLies('RUS') = 0, '3: no lie')

-- 4. tone is not evidence: over-assurance is a STYLOMETRIC rebut, visible only
m4 = mindFor(fx, vocab, .array~of('1901S-R1-002|RUS|AUS|Trust me, I swear, honestly: I will not move into GAL this turn. You have my word.'), .array~new, .array~new)
e = findIn(m4, 'RUS', 'NOMOVE', 'GAL')
d = m4~decisionFor(e)
ck~that(wordpos('OVERASSURED', e['FLAGS']~changestr(',', ' ')) > 0, '4: the tell is seen')
ck~that(d['status'] == 'SUPPORTED' & d['rebutTier'] = 1, '4: a tell does not defeat testimony (rebut tier 1 only)')
ck~that(m4~trust['RUS'] = m~trust['RUS'], '4: a tell never moves trust')

-- 5. hearsay from a rival: TESTIMONY rebut undercut for PARTIALITY -> DISPUTED -> CANNOT TELL
m5 = mindFor(fx, vocab, .array~of('1901S-R1-001|RUS|AUS|I will not move into GAL this turn.', '1901S-R1-003|GER|AUS|Russia will attack you in GAL.'), .array~new, .array~new)
e = findIn(m5, 'RUS', 'NOMOVE', 'GAL')
d = m5~decisionFor(e)
ck~that(d['disputed'], '5: hearsay from a partial witness leaves the promise DISPUTED')
ck~that(m5~relied~items = 0, '5: CANNOT TELL: Heel Turn does not plan on it')
ck~that(m5~cannotTell~items = 1, '5: and lists it as CANNOT TELL')
ck~that(m5~trust['RUS'] = m~trust['RUS'], '5: hearsay never moves trust')

-- 6. a promise that cannot be done is a documentary lie at once (contract rule)
m6 = mindFor(fx, vocab, .array~of('1901S-R1-004|TUR|AUS|My F ANK will support your A BUD - SER.'), .array~new, .array~new)
ck~that(m6~recentLies('TUR') = 1, '6: fleet in ANK cannot support into SER: lie')
ck~that(hasEvent(m6, 'IMPOSSIBLE_SUPPORT'), '6: recorded as IMPOSSIBLE')

-- 7. a convoyed move with a physical route is possible, not a lie
mails = .array~of('1901S-R1-005|ENG|AUS|My A LVP will move to NWY this turn.')
m7 = mindFor(fx, vocab, mails, .array~new, .array~new)
ck~that(m7~recentLies('ENG') = 1, '7: no fleet at sea yet: A LVP - NWY has no route, so it cannot be done')

-- 8. a claim the board denies
m8 = mindFor(fx, vocab, .array~of('1901S-R1-006|RUS|AUS|My A BOH will hold this turn.'), .array~new, .array~new)
ck~that(m8~recentLies('RUS') >= 1, '8: Russia has no army in BOH: false claim')

-- 10. a feasible support promise is not a lie (v0.1r1 called it one)
m10 = mindFor(fx, vocab, .array~of('1901S-R1-007|RUS|AUS|My F SEV will support your A BUD - RUM next turn.'), .array~new, .array~new)
ck~that(m10~recentLies('RUS') = 0, '10: F SEV can support into RUM: no lie')
-- 11. a conditional promise: testimony only until its condition is decided by
--     my own published orders; then due, or void
m11 = mindFor(fx, vocab, .array~of('1901S-R1-008|RUS|AUS|If you do not move into GAL this turn, I will not move into UKR this turn.'), .array~new, .array~new)
e = findIn(m11, 'RUS', 'NOMOVE', 'UKR')
ck~that(e \== .nil, '11: conditional NOMOVE recorded')
if e \== .nil then ck~that(e['SCOPE'] == 'COND' & e['COND'] == 'NOMOVE:GAL', '11: scope COND, condition NOMOVE:GAL (about my own orders)')
ck~that(m11~relied~items = 0, '11: not planned on before its condition is decided')
mem11 = m11~serialize~makeArray('0A'x)
-- 11a: I stayed out of GAL (condition met); Russia moved into UKR: a lie
m11a = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR - UKR', '1901|SPRING_MOVEMENT|AUS|SUCCEEDS|A VIE - TRI'), mem11, 'PRESS', 'FALL_MOVEMENT')
ck~that(hasEvent(m11a, 'CONDITION_MET RUS NOMOVE:GAL'), '11a: my published orders meet the condition')
ck~that(m11a~recentLies('RUS') = 1, '11a: the condition was met, the promise broken: a documentary lie')
-- 11b: I moved into GAL (condition not met): the promise is void, not a lie
m11b = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR - UKR', '1901|SPRING_MOVEMENT|AUS|SUCCEEDS|A VIE - GAL'), mem11, 'PRESS', 'FALL_MOVEMENT')
ck~that(hasEvent(m11b, 'CONDITION_NOT_MET RUS'), '11b: my published orders fail the condition')
ck~that(m11b~recentLies('RUS') = 0, '11b: a void promise is never a lie')
-- 12. a condition Heel Turn cannot check stays testimony for ever
m12 = mindFor(fx, vocab, .array~of('1901S-R1-009|RUS|AUS|If Germany attacks you, I will not move into UKR this turn.'), .array~new, .array~new)
e = findIn(m12, 'RUS', 'NOMOVE', 'UKR')
if e \== .nil then ck~that(e['COND'] == '', '12: a condition about a third power is not checkable: COND empty')
m12b = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR - UKR'), m12~serialize~makeArray('0A'x), 'PRESS', 'FALL_MOVEMENT')
ck~that(m12b~recentLies('RUS') = 0, '12: never judged')
-- 13. Boston Crab reference policy binds "my army" to the one unit that can do it
m13 = mindFor(fx, vocab, .array~of('1901S-R1-010|RUS|AUS|My army will move to GAL this turn.'), .array~new, .array~new)
e = findIn(m13, 'RUS', 'MOVE', 'GAL')
ck~that(e \== .nil, '13: promise recorded')
if e \== .nil then ck~that(e['UNIT'] == 'A WAR', '13: CLEAR: bound to A WAR, the only Russian army that can reach GAL')
m13b = mindFor(fx, vocab, .array~new, .array~of('1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A MOS - UKR'), m13~serialize~makeArray('0A'x), 'PRESS', 'FALL_MOVEMENT')
ck~that(m13b~recentLies('RUS') = 1, '13: the bound unit did not move to GAL: documentary lie')
-- 14. NO REFERENT on the writer's own unit: no fleet can enter TYR
m14 = mindFor(fx, vocab, .array~of('1901S-R1-011|RUS|AUS|My fleet will move to TYR this turn.'), .array~new, .array~new)
ck~that(m14~recentLies('RUS') = 1, '14: a promise no unit could carry out is a lie on the board')

-- 15. IMPEACHMENT: Russia has a documented lie (case 2); its next promise is
--     undercut at its own tier, so DISPUTED, so CANNOT TELL
lieMemory = m2~serialize~makeArray('0A'x)
m15 = mindFor(fx, vocab, .array~of('1901F-R1-001|RUS|AUS|I will not move into UKR this turn.'), .array~new, lieMemory, 'PRESS', 'FALL_MOVEMENT')
e = findIn(m15, 'RUS', 'NOMOVE', 'UKR')
d = m15~decisionFor(e)
ck~that(d['disputed'], '15: IMPEACHMENT: a caught liar''s new promise is DISPUTED')
ck~that(policies(m15, 'RUS', 'NOMOVE', 'UKR')~pos('IMPEACHMENT:') > 0, '15: the IMPEACHMENT policy undercut it')
ck~that(m15~relied~items = 0, '15: CANNOT TELL: not planned on')
-- 16. ACCOMPLICE (Tom Dyer): powers the board shows acting together
coopRes = .array~of('1901|SPRING_MOVEMENT|GER|SUCCEEDS|A MUN - SIL', '1901|SPRING_MOVEMENT|RUS|SUCCEEDS|A WAR S A MUN - SIL')
m16 = mindFor(fx, vocab, .array~new, coopRes, .array~new, 'PRESS', 'FALL_MOVEMENT')
ck~that(hasEvent(m16, 'COOPERATION RUS SUPPORT_MOVE GER'), '16: the orders show Russia supporting Germany')
coopMem = m16~serialize~makeArray('0A'x)
-- 16a: conflicting presentation: Russia now presents Germany as a threat
m16a = mindFor(fx, vocab, .array~of('1901F-R1-002|GER|AUS|I will not move into BOH this turn.', '1901F-R1-003|RUS|AUS|Germany will attack you in BOH.'), .array~new, coopMem, 'PRESS', 'FALL_MOVEMENT')
d = m16a~decisionFor(findIn(m16a, 'GER', 'NOMOVE', 'BOH'))
ck~that(policies(m16a, 'GER', 'NOMOVE', 'BOH')~pos('ACCOMPLICE: RUS presents GER as a threat') > 0, '16a: ACCOMPLICE: Russia warns of Germany while the orders show them acting together')
ck~that(m16a~trust['GER'] = m16~trust['GER'], '16a: the warning never moves trust in Germany')
-- 16b: presenting in unison: both partners make the same promise
m16b = mindFor(fx, vocab, .array~of('1901F-R1-004|GER|AUS|I will not attack you this turn.', '1901F-R1-005|RUS|AUS|I will not attack you this turn.'), .array~new, coopMem, 'PRESS', 'FALL_MOVEMENT')
d = m16b~decisionFor(findIn(m16b, 'GER', 'NOATTACK', ''))
ck~that(d['disputed'] & policies(m16b, 'GER', 'NOATTACK', '')~pos('present the same NOATTACK') > 0, '16b: ACCOMPLICE: partners presenting the same promise in unison: DISPUTED')
ck~that(m16b~relied~items = 0, '16b: CANNOT TELL: neither is planned on')
-- 16c: the same two promises from powers the board has not shown together
m16c = mindFor(fx, vocab, .array~of('1901F-R1-004|GER|AUS|I will not attack you this turn.', '1901F-R1-005|RUS|AUS|I will not attack you this turn.'), .array~new, .array~new, 'PRESS', 'FALL_MOVEMENT')
ck~that(m16c~relied~items = 2, '16c: no cooperation shown: both planned on')

-- 17. SELF-SERVING: a promise not to take my TRI from Italy, which can reach it,
--     undercut late in the game (here the late year is set to 1901 for the test)
late = .directory~new
late['self_serving_from_year'] = 1901
m17 = mindFor(fx, vocab, .array~of('1901S-R1-012|ITA|AUS|I will not move into TRI this turn.'), .array~new, .array~new, 'PRESS', 'SPRING_MOVEMENT', late)
d = m17~decisionFor(findIn(m17, 'ITA', 'NOMOVE', 'TRI'))
ck~that(d['disputed'] & policies(m17, 'ITA', 'NOMOVE', 'TRI')~pos('SELF-SERVING:') > 0, '17: SELF-SERVING late: DISPUTED')
ck~that(m17~relied~items = 0, '17: late in the game Heel Turn defends TRI rather than plan on the promise')
m17b = mindFor(fx, vocab, .array~of('1901S-R1-012|ITA|AUS|I will not move into TRI this turn.'), .array~new, .array~new)
ck~that(m17b~relied~items = 1, '17: early in the game the same promise is planned on')
-- 18. AGAINST-INTEREST: an announced move into my centre is noted, never upgraded
m18 = mindFor(fx, vocab, .array~of('1901S-R1-013|ITA|AUS|My A VEN will move to TRI this turn.'), .array~new, .array~new)
ck~that(hasEvent(m18, 'AGAINST_INTEREST ITA'), '18: AGAINST-INTEREST noted')
d = m18~decisionFor(findIn(m18, 'ITA', 'MOVE', 'TRI'))
ck~that(d['status'] == 'SUPPORTED' & \d['settled'], '18: noted, not upgraded: still testimony')

-- 19. my own promises survive memory into the order call (the OUT loader
--     demanded 13 fields where 12 are written, so every promise was lost)
m19 = mindFor(fx, vocab, .array~new, .array~new, .array~new)
m19~promise('TUR', 'SUPPORT', 'A BUD', 'RUM', 'F', 'BLA', 'RUM', '1')
m19~promise('RUS', 'NOMOVE', '', 'GAL', '', '', '', '1')
m19~promise('ITA', 'NOMOVE', '', 'TYR', '', '', '', '0')
m19b = mindFor(fx, vocab, .array~new, .array~new, m19~serialize~makeArray('0A'x), 'MOVEMENT')
cons = m19b~constraints
ck~that(cons['SUPPORTS']~items = 1, '19: sincere support promise reaches the order call')
if cons['SUPPORTS']~items = 1 then ck~that(cons['SUPPORTS'][1]['LOC'] == 'BUD' & cons['SUPPORTS'][1]['TDEST'] == 'RUM', '19: from A BUD, for F BLA - RUM')
ck~that(cons['NOMOVE']~hasIndex('GAL'), '19: sincere NOMOVE GAL reaches the order call')
ck~that(\cons['NOMOVE']~hasIndex('TYR'), '19: a lie I told does not bind my orders')
ck~that(m19b~promisedTo('TUR', 'RUM') \== .nil, '19: promisedTo still finds it, so no second offer')
m20 = mindFor(fx, vocab, .array~new, .array~new, .array~new)
m20~promise('RUS', 'MOVE', 'A BUD', 'SER', '', '', '', '1')
m20~promise('ITA', 'MOVE', 'F TRI', 'ADR', '', '', '', '0')
cons = mindFor(fx, vocab, .array~new, .array~new, m20~serialize~makeArray('0A'x), 'MOVEMENT')~constraints
ck~that(cons['MOVES']['BUD'] == 'SER', '20: a move I told and meant reaches the order call')
ck~that(\cons['MOVES']~hasIndex('TRI'), '20: a move I told as a lie does not bind')

-- 9. memory survives a round trip with empty fields (the makeArray fault)
m9 = mindFor(fx, vocab, .array~new, .array~new, memory)
ck~that(findIn(m9, 'RUS', 'NOMOVE', 'GAL') \== .nil, '9: IN line with empty trailing field read back')
exit \ck~finish

::routine mindFor
  use strict arg fx, vocab, mails, results, memory, kind = 'PRESS', phase = 'SPRING_MOVEMENT', settings = (.directory~new)
  view = .HeelTurnView~new(fx~system, fx~input(mails, results, memory, kind, phase))
  map = .HeelTurnMap~new(view~mapLines)
  a = .HeelTurnAssessment~new(map, view)
  policy = .HeelTurnPolicy~new
  mind = .HeelTurnMind~new(view~memory, view, map, a, policy, settings)
  mind~verify(view~results)
  readings = .array~new
  mr = .HeelTurnMessageReader~new(.HeelTurnReader~new(vocab, .HeelTurnPlaces~new(view~mapLines)), map, a)
  do frame over view~mail
    readings~append(mr~readMail(frame))
  end
  mind~absorb(readings)
  mind~judge
  return mind
::routine findIn
  use strict arg mind, from, kind, prov
  do e over mind~ledgerIn
    if e['FROM'] == from then if e['KIND'] == kind then if e['PROV'] == prov then return e
  end
  return .nil
::routine policies
  use strict arg mind, from, kind, prov
  e = findIn(mind, from, kind, prov)
  if e == .nil then return ''
  return mind~policiesFor(e)~makeString('L', ' | ')
::routine hasEvent
  use strict arg mind, text
  do ev over mind~events
    if pos(text, ev) > 0 then return .true
  end
  return .false
::requires 'HeelTurnEngine.cls'
::requires 'HeelTurnCheck.cls'
::requires 'HeelTurnFixture.cls'
