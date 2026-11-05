/* bank_rt.rex - the three witness statements as Reasoned Thought would weigh them.
   Hand-encoded here as the propositions and grounds the reader should emit, so the
   mapping can be checked before the reader is built. Decisions come from Reasoned
   Thought's own ordinal combiner, not from this script.
   Architecture: Tom Dyer. Reasoned Thought: Claude (Opus 4.8) / ChatGPT. This file: Claude (Opus 5.5). */
parse arg withRecord .
net = .ThoughtNetwork~new
/* HEARSAY is a binding scope: "I heard that X" proves what was said to Noah, not X itself.
   No proposition below accepts it, so hearsay grounds are INELIGIBLE. */
net~propose('LIAM_AT_BANK', 'Liam was at the bank, about 3:10-3:20', 'DOCUMENTARY')
net~propose('NOAH_AT_BANK', 'Noah was at the bank, about 3:10-3:20', 'DOCUMENTARY')
net~propose('GUN_FIRED',    'A gun was fired in the bank', 'DOCUMENTARY')
net~propose('NOAH_HAD_GUN', 'Noah had the (black) gun', 'DOCUMENTARY')

u = .Utterance~new('LIAM', 'Statement 1 - Liam Carter')
u~assert('SUPPORT', 'TESTIMONY', 'LIAM_AT_BANK', '', 'GENERAL', 'own account, against his own interest', 'L1')
u~assert('SUPPORT', 'TESTIMONY', 'NOAH_AT_BANK', '', 'GENERAL', 'Noah was with me at the bank', 'L2')
u~assert('REBUT',   'TESTIMONY', 'GUN_FIRED',    '', 'GENERAL', 'Nobody fired a gun', 'L3')
u~assert('SUPPORT', 'TESTIMONY', 'NOAH_HAD_GUN', '', 'GENERAL', 'Noah had a black gun', 'L4')
call show net~admit(u), 'after Liam'

u = .Utterance~new('NOAH', 'Statement 2 - Noah Carter')
u~assert('REBUT',   'TESTIMONY', 'NOAH_AT_BANK', '', 'GENERAL', 'I was at the supermarket', 'N1')
u~assert('SUPPORT', 'TESTIMONY', 'LIAM_AT_BANK', '', 'HEARSAY', 'I heard Liam went into the bank alone', 'N2')
u~assert('SUPPORT', 'TESTIMONY', 'GUN_FIRED',    '', 'HEARSAY', 'I heard Liam fired at the ceiling', 'N3')
u~assert('REBUT',   'TESTIMONY', 'NOAH_HAD_GUN', '', 'GENERAL', 'I never had a black gun', 'N4')
/* Noah is accused: his denial is self-serving, an equal-tier undercut of his own link */
u~assert('UNDERCUT', 'TESTIMONY', 'NOAH_AT_BANK', 'N1', 'GENERAL', 'interest: he is the accused', 'N5')
/* and Liam, caught, has reason to share the blame */
u~assert('UNDERCUT', 'TESTIMONY', 'NOAH_AT_BANK', 'L2', 'GENERAL', 'interest: Liam was caught and gains by sharing blame', 'N6')
call show net~admit(u), 'after Noah'

u = .Utterance~new('EMMA', 'Statement 3 - Emma Price')
u~assert('REBUT',   'TESTIMONY', 'LIAM_AT_BANK', '', 'GENERAL', 'Liam stood next to me at 3:15 in the supermarket', 'E1')
u~assert('REBUT',   'TESTIMONY', 'NOAH_AT_BANK', '', 'GENERAL', 'Noah was with me', 'E2')
u~assert('REBUT',   'TESTIMONY', 'NOAH_HAD_GUN', '', 'GENERAL', 'None of us had a gun', 'E3')
u~assert('UNDERCUT', 'TESTIMONY', 'NOAH_AT_BANK', 'E2', 'GENERAL', 'interest: Noah is her boyfriend', 'E4')
call show net~admit(u), 'after Emma'

if withRecord == 'record' then do
  /* if the police arrest record is admitted: documentary, on point for Liam's location,
     and it impeaches Emma's account of 3:15, which places Liam elsewhere */
  u = .Utterance~new('POLICE', 'Arrest record: Liam Carter detained outside the bank, 3:20 pm')
  u~assert('SUPPORT',  'DOCUMENTARY', 'LIAM_AT_BANK', '', 'GENERAL', 'arrest outside the bank at 3:20', 'R1')
  u~assert('UNDERCUT', 'DOCUMENTARY', 'NOAH_AT_BANK', 'E2', 'GENERAL', 'Emma is shown wrong about who was with her at 3:15', 'R2')
  call show net~admit(u), 'after the arrest record'
end

say
say 'Decisions' (withRecord == 'record')~?('(with the arrest record)', '(testimony only)')
do id over .array~of('LIAM_AT_BANK', 'NOAH_AT_BANK', 'GUN_FIRED', 'NOAH_HAD_GUN')
  d = net~assess(id)
  inel = ''
  if d['ineligible'] \== .nil then inel = d['ineligible']~items 'ineligible'
  say left(id, 14) left(d['stance'], 12) left(d['status'], 12) 'settled='d['settled'] 'assertible='d['assertible'] inel
  w = d['why']
  if w~isA(.Array) then do x over w
    say '                 ' x
  end
  else say '                 ' w
end
exit 0

show: procedure
  use arg rep, label
  return

::requires 'ReasonedThought.cls'
