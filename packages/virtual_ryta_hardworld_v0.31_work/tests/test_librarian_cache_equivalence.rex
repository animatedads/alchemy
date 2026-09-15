say 'LIBRARIAN CACHE EQUIVALENCE START'
lexicon=.LibrarianLexicon~new
graph=.LibrarianRelationGraph~new
s1=lexicon~addSense('AMB','N','noun.person','100','AMB','noun','fixture')
s2=lexicon~addSense('AMB','V','verb.motion','200','AMB','verb','fixture')
s3=lexicon~addSense('AMB','ADJ','adj.all','300','AMB','adj','fixture')
s4=lexicon~addSense('AMB','ADV','adv.all','400','AMB','adv','fixture')
runSense=lexicon~addSense('RUN','V','verb.motion','500','RUN','run','fixture')
lexicon~addException('RAN','V','RUN')
ignore=graph~link(lexicon~word('AMB'),'RELATED',lexicon~word('RUN'),1,'fixture','cache-equivalence')
direct=lexicon~word('AMB')~primarySense('')
call AssertTrue direct~posKind='N', 'direct primary N'
call AssertTrue direct~offset='100', 'direct primary offset 100'
tmp='/tmp/librarian_cache_' || random(100000,999999) || '.txt'
cache=.LibrarianLexiconCache~new(lexicon,graph)
call AssertTrue cache~saveFile(tmp)=0, 'cache saved'
tmp2='/tmp/librarian_cache_2_' || random(100000,999999) || '.txt'
call AssertTrue cache~saveFile(tmp2)=0, 'second cache saved'
s1=.Stream~new(tmp); text1=s1~charin(1,s1~chars); s1~close
s2=.Stream~new(tmp2); text2=s2~charin(1,s2~chars); s2~close
call AssertTrue text1=text2, 'cache serialization canonical and reproducible'
call AssertTrue linein(tmp)='LIBRARIAN-OOREXX-CACHE|2', 'cache format v2'
call stream tmp, 'c', 'close'
lex2=.LibrarianLexicon~new
graph2=.LibrarianRelationGraph~new
cache2=.LibrarianLexiconCache~new(lex2,graph2)
call AssertTrue cache2~loadFile(tmp)=0, 'cache loaded'
round=lex2~word('AMB')~primarySense('')
call AssertTrue round~posKind=direct~posKind, 'cache primary POS preserved'
call AssertTrue round~offset=direct~offset, 'cache primary offset preserved'
call AssertTrue lex2~exceptionLemma('RAN','V')='RUN', 'cache exception mapping preserved'
related=graph2~relatedWords(lex2~word('AMB'),'RELATED')
call AssertTrue related~items=1, 'cache relation edge count preserved'
call AssertTrue related[1]~key='RUN', 'cache relation edge target preserved'
ignore=SysFileDelete(tmp)
ignore=SysFileDelete(tmp2)
say 'LIBRARIAN CACHE EQUIVALENCE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianCore.cls'
