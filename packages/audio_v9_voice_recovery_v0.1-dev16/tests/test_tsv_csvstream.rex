numeric digits 30
pass=0
parse arg root
if root='' then root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
p=root||'/run/test/tsv_csvstream.tsv'
call stream p,'C','OPEN WRITE REPLACE'
call lineout p,'a'||'09'x||'b'||'09'x||'c'
call lineout p,'1'||'09'x||''||'09'x||'3'
call lineout p,'4'||'09'x||'two words'||'09'x||'6'
call lineout p,'7'||'09'x||'8'||'09'x
call stream p,'C','CLOSE'
r=.AudioV9TsvReader~new(p,.array~of('a','b','c'))
row=r~next; call ok row~items=3,'first data row width'; call ok row[1]='1','first field'; call ok row[2]='','empty middle field preserved'; call ok row[3]='3','third field'
row=r~next; call ok row~items=3,'second data row width'; call ok row[2]='two words','literal whitespace preserved'
row=r~next; call ok row~items=3,'trailing-empty row width'; call ok row[1]='7','trailing-empty first field'; call ok row[3]='','trailing empty field preserved'
call ok r~next==.nil,'end of TSV returns NIL'
r~close
say 'PASS TSV CSVStream assertions='pass
exit 0
ok: procedure expose pass
  use arg cond,msg
  if \cond then do; say 'FAIL '||msg; exit 1; end
  pass=pass+1
  return
::requires 'AudioV9Tsv.cls'
