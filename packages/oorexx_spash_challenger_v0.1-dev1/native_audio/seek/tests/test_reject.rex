parse arg test
p=.SpashNativeOggSeek~new('mock-bridge')
select
 when test=='ZERO_DURATION' then result=p~decode('a.ogg','out.f32','report.tsv',0,0,1000,0,8000,64)
 when test=='TOO_LONG' then result=p~decode('a.ogg','out.f32','report.tsv',0,0,1000,120001,8000,64)
 when test=='BAD_CHANNEL' then result=p~decode('a.ogg','out.f32','report.tsv',0,32,1000,6000,8000,64)
 when test=='BAD_RATE' then result=p~decode('a.ogg','out.f32','report.tsv',0,0,1000,6000,11025,64)
 when test=='BAD_BUDGET' then result=p~decode('a.ogg','out.f32','report.tsv',0,0,1000,6000,8000,129)
 when test=='SOURCE_COLLISION' then result=p~decode('a.ogg','a.ogg','report.tsv',0,0,1000,6000,8000,64)
 when test=='BAD_CATALOGUE' then result=p~catalogue('a.ogg','a.ogg',64)
 otherwise say 'Invalid test';exit 5
end
say 'FAILED_TO_REJECT' test
exit 0
::requires 'SpashNativeOggSeek.cls'
