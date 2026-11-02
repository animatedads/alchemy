/* Native synthetic cycle test; does not claim real-world PTZ calibration */
a=.HarbourPtzCycle~new
if a~estimate(8,15,30)['STATUS']<>'TOO_FEW_FRAMES' then call fail 'short'
/* Diverse feature patterns with exact periodic repeat every 11 frames */
do i=1 to 55
  sig=.array~new(72)
  do k=1 to 72
    sig[k]=((i-1)//11 * (k*19+7) + k*13)//251
  end
  a~appendSignature(sig)
end
z=a~estimate(8,15,30)
if z['PERIOD_SECONDS']<>11 then call fail 'period'
if z['OVERLAP_PAIRS']<>30 then call fail 'overlap'
if z['MEAN_ABS_8BIT']<>0 then call fail 'score'
if z['STATUS']<>'PTZ_PERIOD_CANDIDATE_UNQUALIFIED' then call fail 'admission'
if a~estimate(54,60,30)['STATUS']<>'NO_OVERLAP' then call fail 'no overlap'
if a~estimate(2,2,30)['STATUS']<>'BAD_SEARCH_BOUNDS' then call fail 'bad bounds'
if a~count<>55 then call fail 'count'
/* A constant scene should not become a qualified pose */
b=.HarbourPtzCycle~new
sig=.array~new(72)
do k=1 to 72;sig[k]=12;end
do j=1 to 50;b~appendSignature(sig);end
z=b~estimate(8,15,20)
if z['STATUS']<>'PTZ_PERIOD_CANDIDATE_UNQUALIFIED' then call fail 'constant scene'
say 'PTZ SYNTHETIC PASS 9 checks'
exit 0
fail:
parse arg reason
say 'PTZ FAIL' reason
exit 2

::requires 'SlamHarbourPtzCycle.cls'