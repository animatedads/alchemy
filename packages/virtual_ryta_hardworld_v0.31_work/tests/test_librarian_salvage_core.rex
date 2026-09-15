say 'LIBRARIAN SALVAGE CORE START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
analyzer = .LibrarianDeterministicFixture~buildAnalyzer(topics)
article = .LibrarianArticle~new('DOC-CORE-1', 'We sell product. Warning danger. Medication warning.')
analyzer~analyseArticle(article)
call AssertTrue article~paragraphs~items = 1, 'one paragraph'
call AssertTrue article~targetScore = 46, 'expected target score 46 got ' || article~targetScore
call AssertContains article~concepts, 'SELL', 'concept SELL'
call AssertContains article~concepts, 'MEDICATION', 'concept MEDICATION'
call AssertContains article~targetHits, 'COMMERCIAL', 'commercial target hit'
call AssertContains article~targetHits, 'SAFETY', 'safety target hit'
say '  article_score=' || article~score
say '  target_score=' || article~targetScore
say '  concepts=' || article~concepts
say 'LIBRARIAN SALVAGE CORE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::routine AssertContains
  use arg text, needle, message
  call AssertTrue pos(needle, text) > 0, message || ' text=' || text
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
