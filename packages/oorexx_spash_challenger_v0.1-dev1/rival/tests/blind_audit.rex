/* Synthetic blind matched audit. No protected labels/audio. */
review=.array~new;key=.array~new
.environment~put(review,'REVIEWS');.environment~put(key,'KEYS')
call add 'B7','CALL','A','CANDIDATE'
call add 'B1','NOT_SPEECH','A','CONTROL'
call add 'B4','UNSURE','B','CANDIDATE'
call add 'B9','NOT_SPEECH','B','CONTROL'
call add 'B2','NOT_SPEECH','C','CANDIDATE'
call add 'B3','SPEECH','C','CONTROL'
scores=.SpashRivalBlindAudit~new~score(review,key)
call chk scores~items==1,'single isolated feed/file/stratum/strategy'
r=scores[1]
call chk r['PAIRS_TOTAL']==3,'all three matched pairs accounted'
call chk r['PAIRS_ASSESSABLE']==2,'exclude unsure pair from denominator'
call chk r['PAIRS_UNASSESSABLE']==1,'uncertainty retained'
call chk r['CANDIDATE_CONFIRMED']==1,'one confirmed candidate'
call chk r['CONTROL_CONFIRMED']==1,'one confirmed random control'
call chk r['PAIRED_LIFT']==0,'controls defeat artificial strategy advantage'
call chk r['CANDIDATE_ONLY_WINS']==1,'one candidate-only discordant pair'
call chk r['CONTROL_ONLY_WINS']==1,'one control-only discordant pair'
call chk r['AUTHORITY']=='BLIND_TOM_LABELS_PLUS_MATCHED_RANDOM_CONTROLS_NOT_SOURCE_LOCALISATION','measured review provenance'
say 'SPASH_RIVAL_BLIND_AUDIT_NATIVE_PASS'
exit 0
::routine add
 use strict arg id,label,pair,role
 review=.directory~new;review['BLIND_ID']=id;review['LABEL']=label
 .environment~at('REVIEWS')~append(review)
 k=.directory~new
 k['BLIND_ID']=id;k['PAIR_ID']=pair;k['ROLE']=role
 k['FEED']='FD';k['FILE']='tp07';k['TIME_BLOCK']='11:14:49-11:19:49';k['STRATEGY_ID']='STABILITY_W32'
 k['CONTROL_SAMPLING']='RANDOM_SAME_FILE_TIME_BLOCK'
 .environment~at('KEYS')~append(k)
::routine chk
 use strict arg condition,message
 if \condition then do;say 'FAIL' message;raise syntax 88.900 array(message);end
 say 'PASS' message
::requires 'SpashRivalBlindAudit.cls'