say 'LIBRARIAN MODEL DRIFT START'
root = directory('..')
sourceTopics = root || '/librarian/fixtures/librarian_topics.txt'
tmp = '/tmp/librarian_model_drift_' || random(100000,999999) || '.txt'
inS=.Stream~new(sourceTopics); text=inS~charin(1,inS~chars); inS~close
out=.Stream~new(tmp); ignore=out~open('WRITE REPLACE'); ignore=out~charout(text); ignore=out~close

factory=.LibrarianDeterministicAnalyzerFactory~new(tmp)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,tmp)
provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root)
initialModel=manifest~currentHash
initialSource=provider~sourceManifestHash

out=.Stream~new(tmp); ignore=out~open('WRITE APPEND'); ignore=out~lineout('EXTRA TEST N 1'); ignore=out~close
currentModel=manifest~currentHash
currentSource=provider~sourceManifestHash
call AssertTrue currentModel \= initialModel, 'model closure rehash detects target drift'
call AssertTrue currentSource \= initialSource, 'provider source identity incorporates current model closure'
call AssertTrue provider~sourceFingerprint~length = 64, 'source fingerprint remains sha256'
call AssertTrue provider~sourceFingerprint \= initialModel, 'source fingerprint is bound closure identity, not bare model file hash'
ignore=SysFileDelete(tmp)

say '  initial_model=' || initialModel
say '  changed_model=' || currentModel
say 'LIBRARIAN MODEL DRIFT: OK'
exit 0

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
