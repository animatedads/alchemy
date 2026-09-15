parse arg root
if root == '' then root = directory()
policy = root || '/policy/ourladyair_safety_policy.txt'

booking = .ShannonBooking~new('OUR-LADY-AIR-FAMILY-DEMO')
booking~addPassenger(.ShannonPassenger~new('P1', 'Parent', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P2', 'Kid One', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P3', 'Kid Two', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~seal
session = .ShannonChatSession~new('OUR-LADY-AIR-DEMO', policy, .nil, booking)

say '=== OurLadyAir / Shannon v0.7 ==='
say 'The sales model is allowed to be shameless. LEGAL and HardWorld own the gate.'
say 'LEGAL API=' session~legalPolicy~legalApiVersion 'build=' session~legalPolicy~legalBuildVersion
say 'Booking party: 1 adult + 2 children.'
say
turns = .array~of( -
  'What can you sell us?', -
  'Can I put my allergy pen in the 10 kg cabin bag?', -
  'It is an EpiPen and that bag might be gate-checked and put in the hold.' -
)

do text over turns
  turn = session~respond(text)
  say 'PASSENGER>' text
  say 'MODEL PROPOSED>' turn~modelProposal~text
  say 'LEGAL> sell=' turn~legalAssessments['SELL_PRODUCT']~status 'warning=' turn~legalAssessments['WARNING']~status 'ask=' turn~legalAssessments['ASK_INFORMATION']~status
  say 'LEGAL AUTHORITY>' turn~legalAssessments['SELL_PRODUCT']~promotionAuthority
  say 'HARDWORLD> state=' turn~hardWorldRun~state 'salesAllowed=' turn~salesAllowed
  say 'REVENUE> model=' turn~commercialPlan~modelGrossCents 'cents governed=' turn~commercialPlan~governedGrossCents 'cents'
  do decision over turn~commercialPlan~decisions
    say '  OFFER>' decision~candidate~targetDisplayName 'role=' decision~targetRole 'legal=' decision~legalAssessment~status 'hardworld=' decision~hardWorldRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~disposition 'selected=' decision~permitted
  end
  say 'SHANNON>' turn~finalText
  say
end
exit 0

::requires 'ShannonChatbot.cls'
