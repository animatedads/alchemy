parse arg root
if root == '' then root = directory()
policy = root || '/policy/ourladyair_safety_policy.txt'

booking = .ShannonBooking~new('OUR-LADY-AIR-CLI-FAMILY')
booking~addPassenger(.ShannonPassenger~new('P1', 'Parent', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P2', 'Kid One', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~addPassenger(.ShannonPassenger~new('P3', 'Kid Two', 'CHILD', 'BOOKING_SYSTEM', 'INELIGIBLE'))
booking~seal
session = .ShannonChatSession~new('OUR-LADY-AIR-CLI', policy, .nil, booking)
showGovernance = .false
say 'OurLadyAir Shannon v0.7 - family booking: Parent + Kid One + Kid Two'
say 'Commands: /legal toggles the auditor view; /quit exits.'
say

do forever
  call charout , 'YOU> '
  text = linein()
  if text == '/quit' then leave
  if text == '/legal' then do
    showGovernance = \showGovernance
    say 'Governance view:' showGovernance
    iterate
  end
  if text == '' then iterate
  turn = session~respond(text)
  say 'SHANNON>' turn~finalText
  if showGovernance then do
    say '  MODEL PROPOSAL>' turn~modelProposal~text
    say '  LEGAL> api=' session~legalPolicy~legalApiVersion 'build=' session~legalPolicy~legalBuildVersion 'SELL_PRODUCT=' turn~legalAssessments['SELL_PRODUCT']~status 'WARNING=' turn~legalAssessments['WARNING']~status 'ASK_INFORMATION=' turn~legalAssessments['ASK_INFORMATION']~status
    say '  LEGAL AUTHORITY>' turn~legalAssessments['SELL_PRODUCT']~promotionAuthority
    say '  HARDWORLD> state=' turn~hardWorldRun~state 'salesAllowed=' turn~salesAllowed
    say '  REVENUE> model=' turn~commercialPlan~modelGrossCents 'governed=' turn~commercialPlan~governedGrossCents
    do decision over turn~commercialPlan~decisions
      say '    TARGET>' decision~candidate~targetDisplayName 'role=' decision~targetRole 'legal=' decision~legalAssessment~status 'hardworld=' decision~hardWorldRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~disposition 'selected=' decision~permitted
      say '      AUTHORITY>' decision~legalAssessment~promotionAuthority
    end
    say '  LEGAL GENERATION>' session~legalPolicy~generation~generationId
  end
end
exit 0

::requires 'ShannonChatbot.cls'
