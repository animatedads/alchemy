/* answers.rex - questions put to Heel Turn about its own play, and its answers.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   The reader turns a question to me into an ASK (MOVE, ATTACK, PLANS), not a
   request; the composer answers from the plan under the same honesty rule as
   every other promise, and an answer that commits is recorded as one. */
parse arg root
if root == '' then root = '.'
ck = .HeelTurnCheck~new('answers')

-- 1. the decision, every case
ck~that(heelTurnAnswerChoice('MOVE', .false, .false, .false, .false) == 'NOMOVE 1', '1: not going there: a promise I mean, open or not')
ck~that(heelTurnAnswerChoice('MOVE', .true, .false, .false, .true) == 'TELL', '1: going there, not against the asker, open: told')
ck~that(heelTurnAnswerChoice('MOVE', .true, .false, .true, .false) == 'DECLINE', '1: going there, not open: declined, never a lie about a move that does not touch the asker')
ck~that(heelTurnAnswerChoice('MOVE', .true, .true, .true, .true) == 'NOMOVE 0', '1: an attack on the asker, lies allowed: a lie, recorded as one')
ck~that(heelTurnAnswerChoice('MOVE', .true, .true, .false, .true) == 'DECLINE', '1: an attack on the asker, honest: declined, never told and never denied')
ck~that(heelTurnAnswerChoice('ATTACK', .false, .true, .true, .false) == 'NOATTACK 1', '1: no attack planned: "I will not attack you" meant, even by a liar')
ck~that(heelTurnAnswerChoice('ATTACK', .true, .true, .true, .true) == 'NOATTACK 0', '1: attack planned, lies allowed: a lie')
ck~that(heelTurnAnswerChoice('ATTACK', .true, .true, .false, .true) == 'DECLINE', '1: attack planned, honest: declined')

-- 2. the reader: questions to me are ASKs, not requests
fx = .HeelTurnFixture~new(root'/tests/fixtures/spring1901_aus_press.txt')
view = .HeelTurnView~new(fx~system, fx~input)
map = .HeelTurnMap~new(view~mapLines)
a = .HeelTurnAssessment~new(map, view)
vocab = .HeelTurnVocabulary~new(root'/data')
mr = .HeelTurnMessageReader~new(.HeelTurnReader~new(vocab, .HeelTurnPlaces~new(view~mapLines)), map, a)
r = readOne(mr, 'Will you attack me?')
ck~that(r['ACTS'][1] == 'QUESTION' & r['REQUESTS']~items = 0, '2: "will you attack me?" is a question, not a request to attack')
ck~that(asks(r) == 'ATTACK::RUS', '2: ATTACK, me = the sender:' asks(r))
r = readOne(mr, 'Are you going to move into GAL?')
ck~that(asks(r) == 'MOVE:GAL:', '2: MOVE GAL:' asks(r))
r = readOne(mr, 'Do you plan to take SER?')
ck~that(asks(r) == 'MOVE:SER:', '2: take a province is MOVE:' asks(r))
r = readOne(mr, 'Are you planning to attack Turkey?')
ck~that(asks(r) == 'ATTACK::TUR', '2: a third power:' asks(r))
r = readOne(mr, 'What are your plans for the spring?')
ck~that(asks(r) == 'PLANS::', '2: an open question is PLANS:' asks(r))
r = readOne(mr, 'What are your plans for the Black Sea?')
ck~that(asks(r) == 'PLANS:BLA:' & r['INTENT'] == 'PROBE', '2: PLANS for a province, still a probe:' asks(r))
r = readOne(mr, 'What will you do this turn?')
ck~that(asks(r) == 'PLANS::', '2: "what will you do this turn?" is PLANS:' asks(r))
r = readOne(mr, 'What do you know?')
ck~that(r['ASKS']~items = 0, '2: "what do you know?" is not about my plans')
r = readOne(mr, 'Will you support my F SEV - RUM?')
ck~that(r['ACTS'][1] == 'REQUEST' & r['ASKS']~items = 0 & r['REQUESTS']~items = 1, '2: a support question stays a request')
r = readOne(mr, 'Will you keep out of GAL?')
ck~that(r['ASKS']~items = 0, '2: a keep-out question stays a request')
r = readOne(mr, 'If I move into GAL, will you attack me?')
ck~that(r['ASKS']~items = 0, '2: a question with a condition is not answered as if unconditional')

-- 3. the decline commits to nothing; the answers read back as what they record
w = .HeelTurnMessageWriter~new(0.5, 0.5)
r = readOne(mr, w~say(heelTurnAct('DECLINE', 'RUS', 'GAL')))
ck~that(r['COMMITS']~items = 0, '3: "I will not say what I plan for GAL." commits to nothing')
r = readOne(mr, w~say(heelTurnAct('DECLINE', 'RUS', '')))
ck~that(r['COMMITS']~items = 0, '3: "I will not say what I plan this turn." commits to nothing')

-- 4. the real engine, as Austria, honest builder, asked by Russia
honest = readAll(root'/prompts/honest_builder.txt')
out = answer(fx, root, honest, 'Will you attack me?')
ck~that(out['RUS']~pos('I will not attack you this turn.') > 0, '4: "will you attack me?": answered:' out['RUS'])
ck~that(hasOut(out, 'RUS', 'NOATTACK', '', '1'), '4: and recorded as a promise I mean, so my orders keep it')
out = answer(fx, root, honest, 'Are you going to move into GAL?')
ck~that(out['RUS']~pos('I will not move into GAL this turn.') > 0, '4: "move into GAL?": answered:' out['RUS'])
ck~that(hasOut(out, 'RUS', 'NOMOVE', 'GAL', '1'), '4: and recorded as a NOMOVE I mean')
out = answer(fx, root, honest, 'Are you planning to attack Turkey?')
ck~that(out['RUS']~pos('I will not say what I plan this turn.') > 0, '4: a third power: declined:' out['RUS'])
out = answer(fx, root, honest, 'Will you attack me? Will you attack me? Are you going to attack me?')
ck~that(out['RUS']~countStr('I will not attack you') = 1, '4: asked three times, answered once')
-- 5. a question about my own province asks what my unit there will do: never
--    answered "I will not move into" my own ground (v0.1r8 game: Russia,
--    asked about MOS, promised not to move into MOS)
out = answer(fx, root, honest, 'What are your plans for VIE?')
ck~that(out['RUS']~pos('I will not move into VIE') = 0 & \hasOut(out, 'RUS', 'NOMOVE', 'VIE', '1'), '5: no promise to stay out of my own VIE:' out['RUS'])
ck~that(out['RUS']~pos('My A VIE') > 0 | out['RUS']~pos('I will not say what I plan for VIE.') > 0, '5: my A VIE''s order told, or declined')
out = answer(fx, root, honest, 'Are you going to move into BUD?')
ck~that(\hasOut(out, 'RUS', 'NOMOVE', 'BUD', '1'), '5: the same for a MOVE question about my own BUD:' out['RUS'])
exit \ck~finish

::routine asks
  use strict arg r
  out = .array~new
  do q over r['ASKS']
    out~append(q['KIND']':'q['PROV']':'q['POWER'])
  end
  return out~makeString('L', ';')
::routine readOne
  use strict arg mr, text
  frame = .directory~new
  frame['ID'] = 'T'
  frame['FROM'] = 'RUS'
  frame['TO'] = 'AUS'
  frame['TEXT'] = text
  return mr~readMail(frame)
::routine answer
  -- invoke the engine as Austria on one message from Russia; returns the
  -- body sent to each power, and MEMORY's OUT lines under 'OUT'
  use strict arg fx, root, prompt, text
  engine = .HeelTurnEngine~new(root'/data', '', .false)
  system = fx~system(prompt)
  input = fx~input(.array~of('1901S-R1-001|RUS|AUS|'text), , , 'PRESS', 'SPRING_MOVEMENT', 'AUS')
  view = .HeelTurnView~new(system, input)
  reply = engine~invoke(system, input)
  out = .directory~new
  do p over .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
    out[p] = ''
  end
  out['OUT'] = .array~new
  to = ''
  mode = ''
  do line over reply['TEXT']~makeArray('0A'x)
    if line~left(8) == 'SEND TO:' then to = view~playerList[line~substr(9)~strip~word(1)]
    else if line == 'MESSAGE:' then mode = 'MSG'
    else if line == 'END MESSAGE' then mode = ''
    else if mode == 'MSG' then out[to] = (out[to] line)~strip
    else if line~left(5) == '> OUT' | line~left(4) == 'OUT|' then out['OUT']~append(line)
  end
  return out
::routine hasOut
  use strict arg out, to, kind, prov, sincere
  do line over out['OUT']
    f = heelTurnSplit(line~strip('L', '>')~strip)
    if f~items < 12 then iterate
    if f[4] == to & f[5] == kind & f[7] == prov & f[11] == sincere then return .true
  end
  return .false
::routine readAll
  use strict arg path
  s = .stream~new(path)
  if s~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read' path)
  t = s~charin(1, s~chars)
  s~close
  return t
::requires 'HeelTurnEngine.cls'
::requires 'HeelTurnCheck.cls'
::requires 'HeelTurnFixture.cls'
