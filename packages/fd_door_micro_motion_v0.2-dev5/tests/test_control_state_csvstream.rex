parse arg root .
if root='' then root='.'
q=root||'/qualification/control_roundtrip'
address system 'rm -rf '||quote(q)
address system 'mkdir -p '||quote(q)
if rc<>0 then call fail 'qualification directory'
p=q||'/control.tsv'
s=.FDCheckpointState~new
s~put('source_path','/run/media/Test Volume/fd/source file.mp4')
s~put('empty_value','')
s~put('quoted_value','a"b')
s~put('tab_value','left'||'09'x||'right')
.FDControlFile~write(p,s)
r=.FDControlFile~read(p)
if r==.nil then call fail 'control file did not parse'
if r~get('source_path')<>'/run/media/Test Volume/fd/source file.mp4' then call fail 'space-containing path changed'
if r~get('empty_value','MISSING')<>'' then call fail 'empty final TSV value changed'
if r~get('quoted_value')<>'a"b' then call fail 'quote changed'
if r~get('tab_value')<>('left'||'09'x||'right') then call fail 'embedded TAB changed'
cp=q||'/checkpoint.tsv'; s~write(cp); r2=.FDCheckpointState~read(cp)
if r2~get('empty_value','MISSING')<>'' then call fail 'checkpoint empty value changed'
if r2~get('tab_value')<>('left'||'09'x||'right') then call fail 'checkpoint embedded TAB changed'
say 'PASS CSVStream control/checkpoint round-trip including empty, quote, TAB and spaces'
exit 0
quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
