/* Mirrors public Storage Fabric class API but not a substitute for its persistence. */
original=.StorageRef~new('original:FD',copies('a',64))
derived=.StorageRef~new('layer:FD:virtual',copies('b',64))
cat=.StorageCatalogue~new
storage=.SpashRivalLayers~new
obj=storage~register(cat,derived,original,'STRATEGY_VIEW','STABILITY:W32:G1',1000)
call chk cat~get('layer:FD:virtual')\==.nil,'StorageCatalogue retained layer object'
call chk obj~eas~get('spash.origin_ref')~value=='original:FD','source lineage is durable EA'
call chk obj~eas~get('spash.role')~value=='STRATEGY_VIEW','layer role retained'
call chk obj~eas~get('spash.method')~value=='STABILITY:W32:G1','strategy metadata retained'
refuse=.false
signal on syntax name invalidDup
storage~register(cat,derived,original,'STRATEGY_VIEW','STABILITY:W32:G1',1000)
invalidDup:
refuse=.true
call chk refuse,'immutable layer overwrite rejected'
slots=.SpashRivalMUSharder~new~plan(.SpashRivalCompetition~new~configurations,10)
call chk slots~items==10,'10 MU placements planned'
total=0
 do s over slots
  call chk s['STRATEGIES']~items==10,'10 strategies on each slot'
  call chk s['STATUS']=='PLANNED_NOT_DISPATCHED','no false deployment claim'
  total=total+s['STRATEGIES']~items
 end
call chk total==100,'100 configurations accounted for'
frames=.array~new
 do i=1 to 40
  frames~append(.SpashRivalFrame~new('FD',i*40,1,.7,.9,.9,.array~of(.3,.5,.2),original))
 end
selected=.SpashRivalIntervalSelector~new~select(frames,.SpashRivalStrategy~new('SPECTRAL_STABILITY',8,0,.55))
call chk selected~items==1,'continuous spectral candidate interval emitted'
call chk selected[1]['CLASSIFICATION']=='ACOUSTIC_CANDIDATE_ONLY_NOT_VERIFIED_VOICE','no voice identification claim'
say 'SPASH LAYER/STORAGE/SHARD TEST PASS'
exit 0
::routine chk
 use strict arg state,label
 if \state then do;say 'FAIL' label;exit 1;end
 say 'PASS' label
::requires 'SpashChallenger.cls'