say 'LIBRARIAN WORDNET MANIFEST BUILDER START'
base = '/tmp/librarian_wordnet_manifest_' || random(100000,999999)
db = base || '/dbfiles'
call SysMkDir base
call SysMkDir db

files = .array~of('data.noun','data.verb','data.adj','data.adv','noun.exc','verb.exc','adj.exc','adv.exc')
do name over files
  call WriteFile base || '/' || name, name || ' fixture'
end
call WriteFile db || '/a.db', 'A'
call WriteFile db || '/b.db', 'B'
topics = base || '/topics.txt'
gaz = base || '/gazetteer.txt'
call WriteFile topics, 'SAFETY WARNING N 8'
call WriteFile gaz, 'AIRPORT|INVERNESS|N|1'

manifest = .LibrarianWordNetModelManifestBuilder~build('WORDNET-TEST','1',base,topics,gaz,'',0,'MAX_ROWS=0')
call AssertTrue manifest~mode='FILE_HASHED_COMPLETE', 'wordnet closure complete'
h1 = manifest~currentHash

-- Filesystem location is provenance, not semantic model identity.
base2 = base || '_copy'
db2 = base2 || '/dbfiles'
call SysMkDir base2
call SysMkDir db2
do name over files
  call WriteFile base2 || '/' || name, name || ' fixture'
end
call WriteFile db2 || '/a.db', 'A'
call WriteFile db2 || '/b.db', 'B'
topics2 = base2 || '/topics.txt'
gaz2 = base2 || '/gazetteer.txt'
call WriteFile topics2, 'SAFETY WARNING N 8'
call WriteFile gaz2, 'AIRPORT|INVERNESS|N|1'
copyManifest = .LibrarianWordNetModelManifestBuilder~build('WORDNET-TEST','1',base2,topics2,gaz2,'',0,'MAX_ROWS=0')
call AssertTrue copyManifest~currentHash = h1, 'same semantic model in different root has same hash'

-- Existing file content drift changes identity.
out=.Stream~new(base || '/data.noun'); ignore=out~open('WRITE APPEND'); ignore=out~lineout('changed'); ignore=out~close
h2 = manifest~currentHash
call AssertTrue h2 \= h1, 'WordNet data mutation changes hash'

-- A newly appearing dbfile is part of the closure too.
call WriteFile db || '/c.db', 'C'
h3 = manifest~currentHash
call AssertTrue h3 \= h2, 'dbfiles membership change changes hash'

-- Target and gazetteer artifacts are independently bound.
out=.Stream~new(topics); ignore=out~open('WRITE APPEND'); ignore=out~lineout('COMMERCIAL SELL V 5'); ignore=out~close
h4=manifest~currentHash
call AssertTrue h4 \= h3, 'target mutation changes hash'
out=.Stream~new(gaz); ignore=out~open('WRITE APPEND'); ignore=out~lineout('SHOP|INVERNESS|N|1'); ignore=out~close
h5=manifest~currentHash
call AssertTrue h5 \= h4, 'gazetteer mutation changes hash'

say '  initial=' || h1
say '  final=' || h5
say 'LIBRARIAN WORDNET MANIFEST BUILDER: OK'
exit 0

::routine WriteFile
  use arg path,text
  s=.Stream~new(path)
  ignore=s~open('WRITE REPLACE')
  ignore=s~lineout(text)
  ignore=s~close
  return 1

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianModelManifest.cls'
