say 'LIBRARIAN MODEL CLOSURE CONTRACT START'
root=directory('..')
topics=root || '/librarian/fixtures/librarian_topics.txt'
contract=.LibrarianModelClosureContract
call AssertTrue contract~artefactRoles~items>=10, 'artefact closure enumerated'
call AssertTrue contract~objectRoles~items>=7, 'object closure enumerated'
call AssertTrue contract~hash~length=64, 'closure contract hash sha256'

factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root)
call AssertTrue manifest~isFrozen=1, 'manifest membership frozen by provider publication'
call AssertTrue \provider~hasMethod('ANALYZERFACTORY'), 'provider does not expose analyzer factory'
call AssertTrue provider~determinism=.AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT, 'published fixture meets deterministic contract'

membershipBlocked=0
signal on syntax name MembershipBlocked
manifest~addLogical('LATE_MUTATION','SHOULD_FAIL')
signal off syntax
signal MembershipDone
MembershipBlocked:
  signal off syntax
  membershipBlocked=1
MembershipDone:
call AssertTrue membershipBlocked=1, 'manifest membership mutation blocked'

analyzer=factory~newAnalyzer
call AssertTrue analyzer~modelFrozen=1, 'factory returns frozen analyzer'
mutationBlocked=0
signal on syntax name ObjectMutationBlocked
analyzer~lexicon~addSense('BANANA','N','noun.food','999','BANANA','banana','late')
signal off syntax
signal ObjectMutationDone
ObjectMutationBlocked:
  signal off syntax
  mutationBlocked=1
ObjectMutationDone:
call AssertTrue mutationBlocked=1, 'published model object mutation blocked'

say '  closure_contract_hash=' || contract~hash
say 'LIBRARIAN MODEL CLOSURE CONTRACT: OK'
exit 0

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../librarian/LibrarianModelClosureContract.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
