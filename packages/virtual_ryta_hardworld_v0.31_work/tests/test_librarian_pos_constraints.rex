say 'LIBRARIAN POS CONSTRAINTS START'
lexicon=.LibrarianLexicon~new
graph=.LibrarianRelationGraph~new
grammar=.LibrarianGrammar~new(lexicon)
grammar~installBuiltins
sense=lexicon~addSense('WATCH','V','verb.perception','100','WATCH','observe','fixture')
lexicon~buildSoundexIndex
resolver=.LibrarianResolver~new(lexicon,grammar)
target=.LibrarianTargetModel~new(lexicon,graph)
tmp='/tmp/librarian_pos_' || random(100000,999999) || '.txt'
call lineout tmp, 'TEST WATCH N 7'
call lineout tmp
target~loadFile(tmp)
target~expand
gaz=.LibrarianGazetteer~new(lexicon)
analyzer=.LibrarianAnalyzer~new(lexicon,graph,grammar,resolver,target,gaz)
article=.LibrarianArticle~new('POS1','We watch.')
analyzer~analyseArticle(article)
call AssertTrue article~targetScore=0, 'noun-only WATCH target must not match WATCH/V'
useObj=article~paragraphs[1]~sentences[1]~uses[2]
call AssertTrue useObj~resolvedKey='WATCH', 'WATCH resolved'
call AssertTrue useObj~resolvedPos='V', 'WATCH resolved as verb'
call AssertTrue useObj~targetHitsArray~items=0, 'no target hit'
ignore=SysFileDelete(tmp)
say 'LIBRARIAN POS CONSTRAINTS: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianCore.cls'
