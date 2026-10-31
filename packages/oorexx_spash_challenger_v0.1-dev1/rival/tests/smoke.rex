/* Synthetic + real native Audio V9 source-shape qualification */
realRef=.TestStorageRef~new('storage:original:FD-TP7',copies('a',64))
fake=.array~new
c=.directory~new;c['AUTHORITY']='OBSERVED_SPECTRAL_FEATURES';c['TONAL_PERSISTENCE']=.96;c['FREQUENCY_SWEEP']=.91;c['TWO_TONE_SWITCH']=.1
k=.directory~new;k['AUTHORITY']='OBSERVED_SPECTRAL_FEATURES';k['TONAL_PERSISTENCE']=.95;k['FREQUENCY_SWEEP']=.2;k['TWO_TONE_SWITCH']=.9
fake~append(.SpashRivalFrame~new('FD',0,1,.7,.8,.8,.array~of(.4,.4,.2),realRef))
fake~append(.SpashRivalFrame~new('FD',40,1,.8,.9,.8,.array~of(.4,.4,.2),realRef))
fake~append(.SpashRivalFrame~new('FD',80,1,.9,.9,.8,.array~of(.9,.06,.04),realRef,c))
fake~append(.SpashRivalFrame~new('FD',120,1,.9,.9,.8,.array~of(.8,.1,.1),realRef,k))
call chk fake[3]~confoundStatus=='SIREN_LIKE_VETO','siren-like feature veto'
call chk fake[4]~confoundStatus=='KLAXON_LIKE_VETO','klaxon-like feature veto'
call chk fake[1]~confoundStatus=='UNTESTED_CONFOUND','unknown remains unknown'
x=.SpashRivalCompetition~new
call chk x~configurations~items==100,'exact 100 independent configurations'
r=x~evaluate(fake,10)
call chk r['TRIALS']==100,'100 strategies executed'
call chk r['TOP']~items==10,'top 10 retained'
call chk r['TOP'][1]['AUTHORITY']=='UNSUPERVISED_CANDIDATE_RANKING_NOT_SPEECH_PROOF','no fabricated voice qualification'
ledger=.SpashRivalEventLedger~new
call chk ledger~attach(.directory~new)=='CONTEXT_ONLY_NO_AUDIO_ALIGNMENT','visual timing not falsely aligned'
ce=.directory~new;ce['AUTHORITY']='OBSERVED_AUDIO_VIDEO_CLOCK_ALIGNMENT';ce['UNCERTAINTY_MS']=10
call chk ledger~attach(.directory~new,ce)=='EVENT_STRATUM_ELIGIBLE_NOT_ACOUSTIC_PROOF','verified mapping only event stratum'
parse arg nativePath eventPath
if nativePath\='' then do
  samples=.SpashRivalTsvReader~new~read(nativePath,realRef)
  call chk samples~items>100,'actual Audio V9 measured tracks loaded'
  results=x~evaluate(samples,5)
  call chk results['TRIALS']==100,'100 strategies executed over genuine V9 measurements'
  say 'REAL_AUDIO_V9_ROWS' samples~items
  do rr over results['TOP']
    say 'TOP' rr['STRATEGY_ID'] 'MERIT' rr['MERIT'] 'SELECTED' rr['SELECTED_ROWS'] 'CONF' rr['CONFOUND_VETO_COUNT']
  end
end
if eventPath\='' then do
  events=ledger~read(eventPath)
  call chk events~items>200,'prior video event evidence recovered'
  call chk events[2]['AUDIO_SYNC']=='UNKNOWN','video has no invented audio clock mapping'
  say 'RECOVERED_VIDEO_EVENTS' events~items
end
say 'SPASH RIVAL native ooRexx CHECKS PASS'
exit 0
::routine chk
 use strict arg cond,label
 if \cond then do;say 'FAIL' label;exit 1;end
 say 'PASS' label
::class TestStorageRef
::attribute objectId get
::attribute digest get
::method init
  expose objectId digest
  use strict arg objectId,digest
::requires 'SpashChallenger.cls'