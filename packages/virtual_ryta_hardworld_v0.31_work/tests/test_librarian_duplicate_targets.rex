say 'LIBRARIAN DUPLICATE TARGETS START'
lexicon=.LibrarianLexicon~new
graph=.LibrarianRelationGraph~new
sense=lexicon~addSense('DANGER','N','noun.state','1','DANGER','danger','fixture')

same='/tmp/librarian_dup_same_' || random(100000,999999) || '.txt'
call lineout same, 'ALERT DANGER N 10'
call lineout same, 'ALERT DANGER N 10'
call lineout same
m1=.LibrarianTargetModel~new(lexicon,graph)
m1~loadFile(same)
call AssertTrue m1~isValid=1, 'exact duplicate accepted as collapse'
call AssertTrue m1~seedCount=1, 'exact duplicate collapsed'

conf='/tmp/librarian_dup_conf_' || random(100000,999999) || '.txt'
call lineout conf, 'ALERT DANGER N 10'
call lineout conf, 'ALERT DANGER N 20'
call lineout conf
m2=.LibrarianTargetModel~new(lexicon,graph)
m2~loadFile(conf)
call AssertTrue m2~isValid=0, 'conflicting duplicate rejected'
call AssertTrue m2~validationErrors~items=1, 'one validation error'
call AssertTrue m2~expand=0, 'invalid target model not expanded'
ignore=SysFileDelete(same)
ignore=SysFileDelete(conf)
say 'LIBRARIAN DUPLICATE TARGETS: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianCore.cls'
