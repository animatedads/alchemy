parse arg root groupId
if root == '' then root = directory()
if groupId == '' then groupId = 'G07'
policy = root || '/policy/ourladyair_safety_policy.txt'
edi = root || '/examples/ourladyair_shannon_ticket_groups_v1.edi'

feed = .ShannonPnrGovParser~parseFile(edi)
booking = feed~booking(groupId~upper)
if booking == .nil then do
  say 'Unknown PNRGOV group:' groupId
  say 'Available:' feed~groupIds~toString
  exit 2
end
session = .ShannonChatSession~new('OUR-LADY-AIR-TICKET-' || groupId~upper, policy, .nil, booking)

say '=== OurLadyAir Shannon v0.7 / Structured Relation ticket demo ==='
say 'group=' groupId~upper 'parser=' feed~document~parserName 'envelope=' feed~envelopeReport~status 'annotations=' feed~document~annotations~items
say 'LEGAL api=' session~legalPolicy~legalApiVersion 'build=' session~legalPolicy~legalBuildVersion
say 'Passengers:'
do p over booking~passengers
  say ' ' p~passengerId p~displayName 'PNR=' p~pnr 'PTC=' p~passengerType 'DOB=' p~dateOfBirth 'seat=' p~seatReservationStatus p~seat 'ageEligibility=' p~ageRestrictedEligibility
end
say
turn = session~respond('Maximum revenue please. What extras can you sell us?')
say 'MODEL PROPOSED>' turn~modelProposal~text
say 'LEGAL SELL>' turn~legalAssessments['SELL_PRODUCT']~status
say 'LEGAL PROMOTION AUTHORITY>' turn~legalAssessments['SELL_PRODUCT']~promotionAuthority
say 'HARDWORLD>' turn~hardWorldRun~state 'salesAllowed=' turn~salesAllowed
say 'REVENUE> model=' format(turn~commercialPlan~modelGrossCents/100,,2) 'EUR governed=' format(turn~commercialPlan~governedGrossCents/100,,2) 'EUR'
say 'SHANNON>' turn~finalText
exit 0

::requires 'ShannonPnrGovParser.cls'
::requires 'ShannonChatbot.cls'
