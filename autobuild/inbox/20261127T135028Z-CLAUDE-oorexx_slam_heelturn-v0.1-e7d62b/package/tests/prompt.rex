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
