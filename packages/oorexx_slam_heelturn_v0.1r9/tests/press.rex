/* press.rex - reading press: speech acts, tone, intent, commitments; and
   the writer's sentences read back as what they commit to.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
parse arg root
if root == '' then root = '.'
ck = .HeelTurnCheck~new('press')
fx = .HeelTurnFixture~new(root'/tests/fixtures/spring1901_aus_press.txt')
view = .HeelTurnView~new(fx~system, fx~input)
map = .HeelTurnMap~new(view~mapLines)
a = .HeelTurnAssessment~new(map, view)
vocab = .HeelTurnVocabulary~new(root'/data')
mr = .HeelTurnMessageReader~new(.HeelTurnReader~new(vocab, .HeelTurnPlaces~new(view~mapLines)), map, a)

r = readOne(mr, "Hi Austria! I'd love to work together. I promise I won't move into Galicia this spring. Could you support my fleet in Sevastopol to the Black Sea?")
ck~that(r['ACTS']~makeString('L', ',') == 'GREETING,PROPOSAL,PROMISE,REQUEST', '1: acts' r['ACTS']~makeString('L', ','))
ck~that(hasCommit(r, 'NOMOVE', 'GAL'), '1: Galicia by name is GAL; "won''t move into" is NOMOVE')
ck~that(r['REQUESTS']~items = 1 & r['REQUESTS'][1]['TLOC'] == 'SEV' & r['REQUESTS'][1]['TDEST'] == 'BLA', '1: support request F SEV - BLA')
ck~that(r['TONE_LABEL'] == 'FRIENDLY' & r['INTENT'] == 'COOPERATE', '1: friendly, cooperative')

r = readOne(mr, "Trust me, I swear I have no plans against you. Honestly, you have my word.")
ck~that(wordpos('OVERASSURED', r['FLAGS']) > 0 & wordpos('EMPTY_ASSURANCE', r['FLAGS']) > 0, '2: over-assurance with nothing concrete is flagged')
ck~that(hasCommit(r, 'NOATTACK', ''), '2: "no plans against you" is a NOATTACK commitment')

r = readOne(mr, "I propose a DMZ in TYR. My A VEN will move to APU this turn.")
ck~that(hasCommit(r, 'NOMOVE', 'TYR') & hasCommit(r, 'MOVE', 'APU'), '3: DMZ and stated move')
ck~that(r['REQUESTS']~items = 1 & r['REQUESTS'][1]['KIND'] == 'NOMOVE', '3: a DMZ asks the reader to stay out too')

r = readOne(mr, "If you move to GAL I will attack you. You will regret it.")
ck~that(r['TONE_LABEL'] == 'HOSTILE' & r['INTENT'] == 'COERCE', '4: threat is hostile, coercive')
ck~that(r['THREATS']~hasItem('GAL'), '4: the threat guards GAL')
ck~that(r['COMMITS']~items = 0, '4: a threat is not a promise')

r = readOne(mr, "You lied to me about SER! Liar.")
ck~that(r['ACTS'][1] == 'ACCUSE' & r['TONE_LABEL'] == 'HOSTILE', '5: accusation')

r = readOne(mr, "Germany is planning to attack you in BOH. Be careful.")
ck~that(r['INTENT'] == 'WEDGE' & r['THIRD']~items = 1 & r['THIRD'][1]['POWER'] == 'GER', '6: hearsay about Germany is a wedge')

r = readOne(mr, "Please support my A BUD - SER.")
ck~that(r['ACTS'][1] == 'REQUEST' & r['REQUESTS'][1]['TLOC'] == 'BUD' & r['REQUESTS'][1]['TDEST'] == 'SER', '7: support request in notation')

r = readOne(mr, "I will support your A VIE - GAL.")
ck~that(hasCommitSupport(r, 'VIE', 'GAL'), '8: support promise')

r = readOne(mr, "What are your plans for the Black Sea?")
ck~that(r['ACTS'][1] == 'QUESTION' & r['INTENT'] == 'PROBE', '9: a question probes')

r = readOne(mr, "Thanks friend, together we are great.")
ck~that(r['ACTS'][1] == 'THANKS' & r['TONE_LABEL'] == 'FRIENDLY', '10: thanks, friendly')

r = readOne(mr, "war is coming, and the gas is cheap")
ck~that(\hasCommit(r, 'MOVE', 'WAR') & r['COMMITS']~items = 0, '11: lower-case war and gas are words, not WAR and GAS')

-- v0.1r2: a conditional term and its explicit forms (sentences written for the test)
r = readOne(mr, "I propose a DMZ in GAL. I will not move into GAL this turn. If you do not attack me this turn, I will help you into a neutral centre next turn.")
ck~that(hasCommit(r, 'NOMOVE', 'GAL'), '12: the DMZ in GAL is a NOMOVE commitment')
ck~that(\hasCommit(r, 'NOATTACK', ''), '12: "if you do not attack me" is the condition, not the writer''s promise')
ck~that(r['ACTS'][3] == 'PROMISE', '12: the conditional help is read as a promise')
r = readOne(mr, "My F SEV will support your A BUD - RUM next turn.")
ck~that(hasCommitSupport(r, 'BUD', 'RUM') & r['COMMITS'][1]['UNIT'] == 'F SEV' & r['COMMITS'][1]['SCOPE'] == 'NEXT', '13: the supporter is the writer''s F SEV, next turn')
r = readOne(mr, "If you do not move into GAL this turn, my F SEV will support your A BUD - RUM next turn.")
ck~that(r['COMMITS']~items = 1 & r['COMMITS'][1]['KIND'] == 'SUPPORT' & r['COMMITS'][1]['SCOPE'] == 'COND', '14: a conditional support is recorded as conditional')

-- v0.1r4: Boston Crab reference verdicts on the board (from RUS, read by AUS)
r = readOne(mr, "My army will move to GAL this turn.")
ck~that(refVerdict(r) == 'CLEAR' & r['COMMITS'][1]['UNIT'] == 'A WAR', '15: "my army" into GAL is CLEAR: A WAR')
r = readOne(mr, "My fleet will move to the Black Sea this turn.")
ck~that(refVerdict(r) == 'CLEAR' & r['COMMITS'][1]['UNIT'] == 'F SEV', '16: "my fleet" to the Black Sea is CLEAR: F SEV')
r = readOne(mr, "I will support your army into GAL.")
ck~that(refVerdict(r) == 'AMBIGUOUS', '17: "your army" into GAL fits A BUD and A VIE: AMBIGUOUS')
r = readOne(mr, "My army will move to the north.")
ck~that(refVerdict(r) == 'WRITER AMBIGUOUS', '18: "my army" with no place fits A MOS and A WAR: WRITER AMBIGUOUS')
r = readOne(mr, "My fleet will move to TYR this turn.")
ck~that(refVerdict(r) == 'NO REFERENT' & r['COMMITS'][1]['UNIT'] == 'F NONE', '19: no fleet can enter TYR: NO REFERENT, bound to no unit')
r = readOne(mr, "If you do not move into GAL this turn, my fleet will support your army into RUM next turn.")
ck~that(r['COMMITS']~items = 1, '20: one conditional commitment')
if r['COMMITS']~items = 1 then ck~that(r['COMMITS'][1]['UNIT'] == 'F SEV' & r['COMMITS'][1]['TLOC'] == 'BUD' & r['COMMITS'][1]['COND'] == 'NOMOVE:GAL' & r['COMMITS'][1]['THEN'] == 'NEXT', '20: F SEV supports A BUD into RUM next turn, if I stay out of GAL')
w = .HeelTurnMessageWriter~new(0.5, 0.5)
d = heelTurnAct('CLARIFY_MINE', 'RUS', 'GAL')
ck~that(w~say(d) == 'Which of my units do you mean for GAL?', '21: clarification asked in fixed English')

-- v0.1r8: the writer's refusals read back as refusals, committing to nothing
w8 = .HeelTurnMessageWriter~new(0.5, 0.5)
r = readOne(mr, w8~say(heelTurnAct('REFUSE_DMZ', 'RUS', 'GAL')))
ck~that(r['ACTS'][1] == 'REFUSE' & r['COMMITS']~items = 0, '14: "I cannot agree to a DMZ in GAL" is a refusal, no NOMOVE:' r['ACTS']~makeString('L', ','))
r = readOne(mr, w8~say(heelTurnAct('REFUSE_SUPPORT', 'RUS', '', 'A BUD')))
ck~that(r['COMMITS']~items = 0, '14: "I cannot support your A BUD" commits to nothing')
r = readOne(mr, 'I agree to a DMZ in GAL.')
ck~that(r['ACTS'][1] == 'ACCEPT' & hasCommit(r, 'NOMOVE', 'GAL'), '14: an unnegated agreement still accepts')
-- round trip: every writer sentence that commits reads back as that commitment
w = .HeelTurnMessageWriter~new(0.5, 0.5)
cases = .array~of('DMZ|GAL|NOMOVE|GAL', 'AGREE_DMZ|TYR|NOMOVE|TYR', 'NOMOVE|VIE|NOMOVE|VIE', 'NOATTACK||NOATTACK|', 'MOVE|SER|MOVE|SER')
do c over cases
  parse var c act '|' prov '|' kind '|' want
  d = heelTurnAct(act, 'RUS', prov, 'A BUD')
  line = w~say(d)
  r = readOne(mr, line)
  ck~that(hasCommit(r, kind, want), 'round trip' act': "'line'"')
end
d = heelTurnAct('GIVE_SUPPORT', 'RUS', 'GAL', 'A WAR')
r = readOne(mr, w~say(d))
ck~that(hasCommitSupport(r, 'WAR', 'GAL'), 'round trip GIVE_SUPPORT: "'w~say(d)'"')
d = heelTurnAct('ASK_SUPPORT', 'RUS', 'SER', 'A BUD')
r = readOne(mr, w~say(d))
ck~that(r['REQUESTS']~items = 1 & r['REQUESTS'][1]['TDEST'] == 'SER', 'round trip ASK_SUPPORT: "'w~say(d)'"')
d = heelTurnAct('THREAT', 'RUS', '')
r = readOne(mr, w~say(d))
ck~that(r['INTENT'] == 'COERCE', 'round trip THREAT reads as COERCE')
d = heelTurnAct('ACCUSE', 'RUS', 'GAL')
r = readOne(mr, w~say(d))
ck~that(r['ACTS'][1] == 'ACCUSE', 'round trip ACCUSE')
exit \ck~finish

::routine readOne
  use strict arg mr, text
  fr = .directory~new
  fr['ID'] = 'T'
  fr['FROM'] = 'RUS'
  fr['TO'] = 'AUS'
  fr['TEXT'] = text
  return mr~readMail(fr)
::routine refVerdict
  use strict arg r
  if r['REFS']~items = 0 then return ''
  return r['REFS'][1]['VERDICT']
::routine hasCommit
  use strict arg r, kind, prov
  do c over r['COMMITS']
    if c['KIND'] == kind then if c['PROV'] == prov then return .true
  end
  return .false
::routine hasCommitSupport
  use strict arg r, tloc, tdest
  do c over r['COMMITS']
    if c['KIND'] == 'SUPPORT' then if c['TLOC'] == tloc then if c['TDEST'] == tdest then return .true
  end
  return .false
::requires 'HeelTurnEngine.cls'
::requires 'HeelTurnCheck.cls'
::requires 'HeelTurnFixture.cls'
