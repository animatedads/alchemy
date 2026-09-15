say 'LIBRARIAN SOUNDEX TIE DETERMINISM START'
key1=ResolveWithOrder(.Array~of('DANGER','DINGER'))
key2=ResolveWithOrder(.Array~of('DINGER','DANGER'))
call AssertTrue key1=key2, 'reverse model insertion order produces same Soundex winner'
call AssertTrue key1='DANGER', 'canonical tie winner is DANGER'
say 'LIBRARIAN SOUNDEX TIE DETERMINISM: OK'
exit 0

::routine ResolveWithOrder
  use arg order
  lexicon=.LibrarianLexicon~new
  do key over order
    ignore=lexicon~addSense(key,'N','noun.state','1',key,'','fixture')
  end
  lexicon~buildSoundexIndex
  grammar=.LibrarianGrammar~new(lexicon)
  resolver=.LibrarianResolver~new(lexicon,grammar)
  resolution=resolver~resolve('DENGER',.nil)
  return resolution~resolvedKey

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianCore.cls'
