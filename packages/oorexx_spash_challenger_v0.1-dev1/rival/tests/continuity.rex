/* Native regression: boundary-sealed continuity and no absolute-time invention. */
refA=.StorageRef~new('original:FD:tp07',copies('a',64))
refB=.StorageRef~new('original:FD:tp08',copies('b',64))
comp=.SpashRivalCompetition~new
selection=.SpashRivalStrategy~new('SPECTRAL_STABILITY',32,0,.55)
call chk comp~configurations~items==100,'one hundred strategy configurations preserved'
frames=.array~new
/* 31 accepted frames in trajectory 2, then only one in trajectory 86. */
do i=1 to 31
  frames~append(.SpashRivalFrame~new('FD',i*40,'2',.8,.85,.9,.array~of(.3,.4,.3),refA))
end
frames~append(.SpashRivalFrame~new('FD',40,'86',.8,.85,.9,.array~of(.3,.4,.3),refA))
r=comp~evaluate(frames,100)
call chk selectedCount(r,selection~id)==0,'W32 cannot bridge trajectory boundary'
call chk .SpashRivalIntervalSelector~new~select(frames,selection)~items==0,'selector cannot bridge trajectory boundary'
/* Same trajectory and same local frame_ms but distinct file: no continuation. */
frames[32]=.SpashRivalFrame~new('FD',32*40,'2',.8,.85,.9,.array~of(.3,.4,.3),refB)
r=comp~evaluate(frames,100)
call chk selectedCount(r,selection~id)==0,'W32 cannot bridge file boundary'
/* Same file and trajectory but unobserved gap > 250 ms. */
frames[32]=.SpashRivalFrame~new('FD',2000,'2',.8,.85,.9,.array~of(.3,.4,.3),refA)
r=comp~evaluate(frames,100)
call chk selectedCount(r,selection~id)==0,'W32 cannot bridge long gap'
/* Repeated/non-monotone ms must reset, even with same feed and track. */
frames[32]=.SpashRivalFrame~new('FD',31*40,'2',.8,.85,.9,.array~of(.3,.4,.3),refA)
r=comp~evaluate(frames,100)
call chk selectedCount(r,selection~id)==0,'W32 cannot bridge duplicate timestamps'
/* Exact 32 frames, valid PTS continuity. */
frames[32]=.SpashRivalFrame~new('FD',32*40,'2',.8,.85,.9,.array~of(.3,.4,.3),refA)
r=comp~evaluate(frames,100)
call chk selectedCount(r,selection~id)==1,'exact 32 frames yields one accepted W32 sample'
call chk r['GROUND_TRUTH_SCORE']==.nil,'no fabricated overall classification score'
intervals=.SpashRivalIntervalSelector~new~select(frames,selection)
call chk intervals~items==1,'one genuine continuous spectral interval'
call chk intervals[1]['TIME_REFERENCE']=='MEASURED_TRACK_FRAME_MS_ORIGIN_UNVERIFIED','time origin explicitly unverified'
call chk intervals[1]['FD_CHAIN_WALL_TIME']=='NOT_DERIVABLE_WITHOUT_TRACK_ORIGIN_MAPPING','no fabricated FD chain wall-time'
call chk intervals[1]['BLIND_REVIEW_SCORE']=='UNSCORED','no score before Tom labels blind batch'
say 'SPASH_RIVAL_CONTINUITY_NATIVE_PASS'
exit 0
::routine selectedCount
  use strict arg result,id
  do entry over result['TOP']
    if entry['STRATEGY_ID']==id then return entry['SELECTED_ROWS']
  end
  raise syntax 88.900 array('strategy id not found')
::routine chk
  use strict arg condition,message
  if \condition then do
    say 'FAIL' message
    raise syntax 88.900 array('regression failed',message)
  end
  say 'PASS' message
::requires 'SpashChallenger.cls'