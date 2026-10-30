/* Observation-level cross-recording example query, no named events. */
.environment~put(0,'SEARCH_OK')
vec=.array~of(7,2,1)
vecAlt=.array~of(1,2,7)
q1=.SpashObservation~new('query-sha',0,100,1000,0,400,100,200,vec,1,.nil,'extract/v1','STFT')
q2=.SpashObservation~new('query-sha',110,100,1000,0,410,100,205,vec,1,.nil,'extract/v1','STFT')
q3=.SpashObservation~new('query-sha',220,100,1000,0,420,100,210,vec,1,.nil,'extract/v1','STFT')
c1=.SpashObservation~new('other-sha',4000,100,1000,0,402,100,202,vec,1,.nil,'different-tool','STFT')
c2=.SpashObservation~new('other-sha',4110,100,1000,0,412,100,207,vec,1,.nil,'different-tool','STFT')
c3=.SpashObservation~new('other-sha',4220,100,1000,0,422,100,211,vec,1,.nil,'different-tool','STFT')
wrong=.SpashObservation~new('other-sha',4600,100,1000,0,1400,100,800,vecAlt,1,.nil,'different-tool','STFT')
search=.SpashExampleSearch~new(.78,.20)
r=search~find(.array~of(q1,q2,q3),.array~of(wrong,c1,c2,c3))
call ok r~items==1,'one three-block match'
call ok r[1]~at('QUERY_START_MS')==0,'query time recorded'
call ok r[1]~at('MATCH_START_MS')==4000,'candidate position is new time'
call ok r[1]~at('MATCH_END_MS')==4320,'candidate end retained'
call ok r[1]~at('LIKENESS')>.95,'high likeness regardless recording gain'
call ok r[1]~at('TIME_SCALE')==1,'temporal scale preserved'
call ok r[1]~at('CANDIDATE_SOURCE_ID')=='other-sha','different source allowed as similarity'
call ok r[1]~at('AUTHORITY')=='ALGORITHM_CANDIDATE_ONLY','search never proof of source identity'
call ok r[1]~at('METHOD_FOUNDATION_ID')=='STFT','shared method foundation disclosed'
call ok search~find(.array~of(q1),.array~of(wrong))~items==0,'negative spectral control'
cOther=.SpashObservation~new('other-sha',0,100,1000,0,400,100,200,vec,1,.nil,'extract/v2','UNRELATED')
call ok search~find(.array~of(q1),.array~of(cOther))~items==0,'incompatible method foundation not silently compared'
call ok search~find(.array~of(q1),.array~of(c1))~items==1,'method IDs can differ when foundation matches'
call ok search~find(.array~of(q1,q2,q3),.array~of(c3,c1,c2))~items==0,'unordered candidate is not reordered silently'
w1=.SpashObservation~new('stretch',4000,110,1000,0,400,100,200,vec,1,.nil,'extract/v1','STFT')
w2=.SpashObservation~new('stretch',4121,110,1000,0,410,100,205,vec,1,.nil,'extract/v1','STFT')
w3=.SpashObservation~new('stretch',4242,110,1000,0,420,100,210,vec,1,.nil,'extract/v1','STFT')
stretch=search~find(.array~of(q1,q2,q3),.array~of(w1,w2,w3))
call ok stretch~items==1,'bounded timing stretch accepted'
call ok stretch[1]~at('TIME_SCALE')>1,'reported time-scale offset'
if .environment~at('SEARCH_OK')<>15 then do
  say 'FAIL search tests' .environment~at('SEARCH_OK')
  exit 1
end
say 'SPASH example search PASS' .environment~at('SEARCH_OK') 'checks'
exit 0
::routine ok
  use strict arg truth,title
  if \truth then do
    say 'FAIL' title
    exit 1
  end
  .environment~put(.environment~at('SEARCH_OK')+1,'SEARCH_OK')
  say 'PASS' title
::requires 'SpashExampleSearch.cls'
