numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
expected=.array~of('landmark_id','feed','source_path','file_nominal_start','absolute_time','offset_seconds','anchor_subsecond_ms','default_pre_seconds','default_post_seconds','annotation_author','observation_class','listening_method','content_cue','follow_on_cue','status')
r=.AudioV9TsvReader~new(root||'/reference/SEARCH_LANDMARKS.tsv',expected)
rows=.array~new
do forever
  row=r~next; if row==.nil then leave; rows~append(row)
end
r~close
call ok rows~items=2,'exactly two current landmarks'
phone=findRow(rows,'LMK-20231010-FC-071312-PHONE')
call ok phone\==.nil,'phone landmark exists'
call ok phone[2]='FC','phone feed preserved'
fileSerial=.AudioV9VoiceClock~parse(phone[4]); eventSerial=.AudioV9VoiceClock~parse(phone[5])
call ok eventSerial-fileSerial=623,'phone file offset is 623 seconds'
call ok eventSerial=63832518792,'phone anchor serial is project clock authority'
call ok phone[7]+0=0,'phone anchor has no subsecond offset'
call ok phone[8]+0=60 & phone[9]+0=240,'phone default probe window preserved'
call ok phone[10]='USER','phone annotation authority preserved'
call ok phone[15]='USER_ANNOTATED','phone interpretation remains annotated'
call ok phone[12]='VLC_200_PERCENT','phone listening method retained'
cal=findRow(rows,'LMK-20231010-041646400-CALIBRATION')
call ok cal\==.nil,'calibration landmark exists'
call ok cal[2]='FC_FD','calibration is paired-feed evidence'
calFile=.AudioV9VoiceClock~parse(cal[4]); calSec=.AudioV9VoiceClock~parse(cal[5])
call ok calSec-calFile=368,'calibration file offset is 368 whole seconds'
call ok calSec=63832508206,'calibration whole-second serial is project clock authority'
call ok cal[7]+0=400,'calibration subsecond offset retained'
call ok calSec*1000+cal[7]=63832508206400,'calibration millisecond anchor retained'
call ok cal[8]+0=6 & cal[9]+0=9,'calibration default probe is tightly bounded'
call ok cal[15]='DERIVED_CANDIDATE','calibration remains candidate not detector truth'
say 'PASS search landmark assertions=18 phone_anchor='||eventSerial||' calibration_anchor_ms='||(calSec*1000+cal[7])
exit 0
findRow: procedure
  use strict arg rows,id
  do row over rows; if row[1]==id then return row; end
  return .nil
ok: procedure
  use arg condition,label
  if condition then return
  say 'FAIL 'label
  exit 1
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9Tsv.cls'
