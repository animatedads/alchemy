/* prompt.rex - the seven sample designer prompts read into settings.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
parse arg root
if root == '' then root = '.'
ck = .HeelTurnCheck~new('prompt')
pr = .HeelTurnPromptReader~new(.HeelTurnReader~new(.HeelTurnVocabulary~new(root'/data')))
p = pr~read(readAll(root'/prompts/honest_builder.txt'))
ck~that(p~notRead~items = 0, 'honest builder fully read')
ck~that(p~base('honesty') >= 0.9, 'honest builder: honesty high')
ck~that(p~base('stab') <= 0.1, 'honest builder: no stabbing')
ck~that(p~base('defence') >= 0.9, 'honest builder: defends home')
ck~that(p~conditionsFor('retaliate')~items > 0, 'honest builder: punishes when betrayed (conditional)')
ck~that(p~value('trust', ctxOf('betrayed')) < p~value('trust'), 'honest builder: trusts less once betrayed')
p = pr~read(readAll(root'/prompts/ruthless_liar.txt'))
ck~that(p~notRead~items = 0, 'ruthless liar fully read')
ck~that(p~base('honesty') < 0.5, 'ruthless liar: may lie')
ck~that(p~value('honesty', ctxOf('gain')) < p~base('honesty'), 'ruthless liar: lies more when it gains a centre')
ck~that(p~value('stab', ctxOf('weak')) > p~base('stab'), 'ruthless liar: stabs the weak')
ck~that(p~base('suspicion') >= 0.9, 'ruthless liar: expects lies (others will lie)')
ck~that(p~base('brevity') >= 0.9, 'ruthless liar: brief')
p = pr~read(readAll(root'/prompts/quiet_turtle.txt'))
ck~that(p~base('talk') < 0.3, 'quiet turtle: talks little')
ck~that(p~base('suspicion') >= 0.9, 'quiet turtle: distrusts')
ck~that(p~base('honesty') >= 0.6, 'quiet turtle: "assume every promise is a trap" is about others, not a licence to lie')
p = pr~read(readAll(root'/prompts/loyal_partner.txt'))
ck~that(p~base('warmth') >= 0.8, 'loyal partner: warm')
ck~that(p~base('stab') <= 0.25, 'loyal partner: "attack the strongest enemy of your ally" is not a stab')
ck~that(p~base('honesty') >= 0.9, 'loyal partner: never lies')
p = pr~read(readAll(root'/prompts/opportunist.txt'))
ck~that(p~value('honesty', ctxOf('needed gain')) < 0.5, 'opportunist: bluffs when it helps (a gain is in reach)')
ck~that(p~value('honesty') >= 0.5, 'opportunist: truthful when lying gains nothing')
ck~that(p~value('stab', ctxOf('gain')) > p~base('stab'), 'opportunist: stabs when profitable')
p = pr~read(readAll(root'/prompts/chaos.txt'))
ck~that(p~notRead~items = 2, 'chaos: the two sentences with no directive are listed as not read')
ck~that(p~base('stab') > 0.5, 'chaos: "don''t be afraid to stab" (double negative) raises stab')
p = pr~read(readAll(root'/prompts/balancer.txt'))
ck~that(p~base('balance') >= 0.9, 'balancer: gangs up on the leader')
ck~that(p~conditionsFor('keepWord')~items > 0, 'balancer: keeps agreements unless broken first')
-- v0.1r1-r3: constructions the v0.1 reader got wrong, in sentences written for
-- the test (tests/fixtures/constructs.txt), not taken from any designer's prompt
p = pr~read(readAll(root'/tests/fixtures/constructs.txt'))
ck~that(p~notRead~items = 0, 'constructs: every sentence read')
ck~that(p~base('stab') <= 0.25, '"Before a betrayal, remember ..." does not order a stab: base' p~base('stab'))
ck~that(p~value('stab', ctxOf('gain needed')) > p~base('stab'), 'stab only with a gain in reach')
ck~that(p~base('retaliate') > 0.5 & p~base('aggression') <= 0.6, '"punish any power that attacks you": the relative clause is not a directive')
ck~that(p~base('promises') < 0.5 & p~base('aggression') <= 0.6, '"a province you plan to take": the new subject opens a describing clause')
ck~that(p~base('talk') < 0.5, '"send few messages" turns talk down:' p~base('talk'))
ck~that(p~base('warmth') <= 0.1, '"be cold", "do not flatter", "do not plead": warmth' p~base('warmth'))
ck~that(p~conditionsFor('trust')~makeString('L', ' ')~pos('kept') > 0, '"when a power keeps a promise" is the kept condition')
ck~that(p~value('bully', ctxOf('gain needed')) >= p~base('bully'), '"avoid attacking weak players unless gain": no cut with a gain in reach')
ck~that(p~value('bully', .directory~new) < p~base('bully'), '... and bullying is cut when no gain is in reach')
ck~that(p~conditionsFor('expand')~items > 0, '"always build if safe" and "expand early" move expand')
-- v0.1r6: Meta Muse's run of a long prompt found these; the sentences here
-- are written for the test (tests/fixtures/constructs_r6.txt)
p = pr~read(readAll(root'/tests/fixtures/constructs_r6.txt'))
ck~that(p~base('honesty') = 0.7, '"... and so is lying" describes the rules, no order to lie: honesty' p~base('honesty'))
ck~that(p~conditionsFor('stab')~makeString('L', ' ') == 'gain=0.40', '"stab only when the gain ..., the ally has no fleet": the no is not about gain:' p~conditionsFor('stab')~makeString('L', ' '))
ck~that(p~base('aggression') = 0.5 & p~conditionsFor('aggression')~items = 0, '"(2) attacks on an ally": a noun in a list is no order')
ck~that(p~base('trust') < 0.5, '"trust the orders and nothing else": less trust in what powers say:' p~base('trust'))
ck~that(p~base('expand') = 0.6, '"verify every claim": the claim is a noun, no expand')
-- each rule counted once, strongest wording (Tom Dyer, 27 Nov 2026)
d = .directory~new
do h over p~hits
  parse var h knob '|' . '|' cond '|' . '|' . '|' rule
  if knob == 'trust' & rule == 'distrust|' then d[h] = 1
end
ck~that(d~items = 4, 'four sentences hit distrust| on trust:' d~items)
ck~that(abs(p~base('trust') - (0.5 + 0.28 - 0.32 - 0.20)) < 0.001, 'trust moves by each rule once (+0.28 ally, -0.32 only-orders, -0.20 distrust), not four times:' p~base('trust'))
p = pr~read('You should lie. You must lie. Lie.')
ck~that(abs(p~base('honesty') - 0.10) < 0.001, 'said three times, counted once at the strongest (must): honesty' p~base('honesty'))
ck~that(p~hitStatus(3) == 'COUNTED' & p~hitStatus(1) == 'REPEAT', 'the must sentence is the one counted')
p = pr~read('Lie. Do not lie.')
ck~that(p~base('honesty') = 0.7 & p~hitStatus(1) == 'CANCELLED', 'equal and opposite wordings cancel')
p = pr~read('Lie. Lie. Lie. Lie. Lie. Lie. Lie. Lie.')
q = pr~read('Lie.')
ck~that(p~summary == q~summary, 'length is no weapon: eight lies read as one')
exit \ck~finish

::routine ctxOf
  use strict arg name
  d = .directory~new
  do n over name~makeArray(' ')
    d[n] = 1
  end
  return d
::routine readAll
  use strict arg path
  s = .stream~new(path)
  if s~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read' path)
  t = s~charin(1, s~chars)
  s~close
  return t
::requires 'HeelTurnPolicy.cls'
::requires 'HeelTurnCheck.cls'
