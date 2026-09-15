say 'LIBRARIAN MODEL FREEZE START'
root=directory('..')
topics=root || '/librarian/fixtures/librarian_topics.txt'
analyzer=.LibrarianDeterministicFixture~buildAnalyzer(topics)
call AssertTrue analyzer~modelFrozen=1, 'fixture returns frozen analyzer'
call AssertTrue analyzer~lexicon~isFrozen=1, 'lexicon frozen'
call AssertTrue analyzer~graph~isFrozen=1, 'graph frozen'
call AssertTrue analyzer~grammar~isFrozen=1, 'grammar frozen'
call AssertTrue analyzer~targetModel~isFrozen=1, 'target model frozen'
call AssertTrue analyzer~gazetteer~isFrozen=1, 'gazetteer frozen'
call AssertTrue \analyzer~resolver~hasMethod('LEXICON='), 'resolver lexicon reference get-only'
call AssertTrue \analyzer~resolver~hasMethod('GRAMMAR='), 'resolver grammar reference get-only'
call AssertTrue \analyzer~grammar~hasMethod('LEXICON='), 'grammar lexicon reference get-only'
call AssertTrue \analyzer~gazetteer~hasMethod('LEXICON='), 'gazetteer lexicon reference get-only'
call AssertTrue \analyzer~targetModel~hasMethod('LEXICON='), 'target model lexicon reference get-only'
call AssertTrue \analyzer~targetModel~hasMethod('GRAPH='), 'target model graph reference get-only'

mutationBlocked=0
signal on syntax name MutationBlocked
analyzer~targetModel~expand
signal off syntax
signal MutationDone
MutationBlocked:
  signal off syntax
  mutationBlocked=1
MutationDone:
call AssertTrue mutationBlocked=1, 'target expansion rejected after freeze'

wordObj=analyzer~lexicon~word('DANGER')
sensesCopy=wordObj~senses
originalCount=wordObj~senses~items
sensesCopy~append(.nil)
call AssertTrue wordObj~senses~items=originalCount, 'word senses backing array not exposed'
termsCopy=analyzer~targetModel~terms
originalTerms=analyzer~targetModel~termCount
termsCopy~append(.nil)
call AssertTrue analyzer~targetModel~termCount=originalTerms, 'target terms backing array not exposed'

sense=wordObj~primarySense('')
call AssertTrue \sense~hasMethod('POSKIND='), 'sense fields get-only'
term=analyzer~targetModel~terms[1]
call AssertTrue \term~hasMethod('WEIGHT='), 'target term fields get-only'

say 'LIBRARIAN MODEL FREEZE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
