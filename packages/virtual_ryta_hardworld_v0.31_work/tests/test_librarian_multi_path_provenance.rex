say 'LIBRARIAN MULTI PATH PROVENANCE START'
lexicon=.LibrarianLexicon~new
graph=.LibrarianRelationGraph~new
grammar=.LibrarianGrammar~new(lexicon)
grammar~installBuiltins
dangerSense=lexicon~addSense('DANGER','N','noun.state','1','DANGER','danger','fixture')
hazardSense=lexicon~addSense('HAZARD','N','noun.state','2','HAZARD','hazard','fixture')
danger=lexicon~word('DANGER')
hazard=lexicon~word('HAZARD')
ignore=graph~link(danger,'SYNONYM',hazard,1,'fixture','')
ignore=graph~link(danger,'DBFILE_LINK',hazard,1,'fixture','')
lexicon~buildSoundexIndex
resolver=.LibrarianResolver~new(lexicon,grammar)
target=.LibrarianTargetModel~new(lexicon,graph)
tmp='/tmp/librarian_paths_' || random(100000,999999) || '.txt'
call lineout tmp, 'SAFETY DANGER N 10'
call lineout tmp
target~loadFile(tmp)
target~expand
gaz=.LibrarianGazetteer~new(lexicon)
analyzer=.LibrarianAnalyzer~new(lexicon,graph,grammar,resolver,target,gaz)
article=.LibrarianArticle~new('PATH1','Hazard.')
analyzer~analyseArticle(article)
wordUse=article~paragraphs[1]~sentences[1]~uses[1]
call AssertTrue wordUse~targetScore=10, 'multi-path evidence scores once'
call AssertTrue wordUse~targetHitsArray~items=1, 'one score contribution'
call AssertTrue wordUse~targetHitProvenanceArray~items=4, 'four provenance paths preserved'
ignore=SysFileDelete(tmp)
say 'LIBRARIAN MULTI PATH PROVENANCE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianCore.cls'
