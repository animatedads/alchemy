say 'LIBRARIAN MODEL MANIFEST START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
manifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
call AssertTrue manifest~mode = 'FILE_HASHED_COMPLETE', 'fixture model closure complete'
call AssertTrue manifest~hash~length = 64, 'manifest hash sha256'

-- A copied/changed target file changes the model closure identity.
tmp = '/tmp/librarian_topics_v010_' || random(100000,999999) || '.txt'
inStream = .Stream~new(topics)
text = inStream~charin(1, inStream~chars)
inStream~close
out = .Stream~new(tmp)
ignore = out~open('WRITE REPLACE')
ignore = out~charout(text || '0a'x || 'EXTRA TEST N 1' || '0a'x)
ignore = out~close
changed = .LibrarianDeterministicFixture~buildModelManifest(root, tmp)
call AssertTrue changed~mode = 'FILE_HASHED_COMPLETE', 'changed model closure complete'
call AssertTrue changed~hash \= manifest~hash, 'target change changes model manifest hash'
ignore = SysFileDelete(tmp)

-- Logical/unbound fixture identity is deliberately not production complete.
unbound = .LibrarianDeterministicFixture~buildModelManifest('', topics)
call AssertTrue unbound~mode = 'INCOMPLETE', 'unbound model manifest incomplete'

say '  model_manifest_hash=' || manifest~hash
say 'LIBRARIAN MODEL MANIFEST: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
