/* Two independent image-only tactical memories. No oracle input. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
p1=.Slam450RaceTactics~new('A1',8)
p2=.Slam450RaceTactics~new('A2',8)
frame=.directory~new
lines=.array~new
do j=1 to 31
  line='.'~copies(360)
  if j==16 then do
    line=overlay('1',line,145)
    line=overlay('R',line,147)
    line=overlay('2',line,260)
  end
  lines~append(line)
end
frame['PIXELS']=lines;frame['WIDTH']=360;frame['HEIGHT']=31
first=p1~choose(frame,1,2,1)
second=p2~choose(frame,1,2,1)
call verify first['ACTION']=='ANTICIPATE_NEXT','rival-aligned cue may favour strategic interception'
call verify second['ACTION']=='ANTICIPATE_NEXT','both independently can initially anticipate'
call verify first['TARGET']==2,'image-only anticipation targets second square'
call verify first['EVIDENCE']=='ONBOARD_IMAGE_AND_PRIVATE_HISTORY','tactic uses restricted data'
call verify first['RIVAL_CUE']=='RIVAL_ALIGNED_WITH_CURRENT_TARGET','coarse rival pixel cue'
call verify p1~outcome(first['DECISION_ID'],'RIVAL_CLAIMED')=='SCORED_FROM_PUBLIC_EVENT','first hypothesis receives loss'
call verify p1~outcome(first['DECISION_ID'],'SELF_CLAIMED')=='ALREADY_SCORED','claim event scored once'
call verify p2~stats~items==0,'other pilot memory has not changed'
again=p1~choose(frame,1,2,2)
call verify again['ACTION']=='CHASE_CURRENT','loss changes the learned tactical choice'
again2=p2~choose(frame,1,2,2)
call verify again2['ACTION']=='ANTICIPATE_NEXT','independent pilot retains original preference'
call verify p1~outcome(again['DECISION_ID'],'SELF_CLAIMED')=='SCORED_FROM_PUBLIC_EVENT','current-target win reinforced'
call verify p1~stats~items==2,'separate context-action statistics'
call verify p2~stats~items==0,'no shared statistics'
blank=.directory~new
hidden=.array~new
do j=1 to 31
  line='.'~copies(360)
  if j==16 then line=overlay('1',line,150)
  hidden~append(line)
end
blank['PIXELS']=hidden;blank['WIDTH']=360;blank['HEIGHT']=31
n=p2~choose(blank,1,2,3)
call verify n['ACTION']=='CHASE_CURRENT','no next-target sighting blocks blind anticipation'
call verify n['RIVAL_CUE']=='NOT_VISIBLE','absent rival not invented'
call verify p1~summary['WORLD_COORDINATES']=='NOT_STORED','no coordinates in tactics memory'
do j=4 to 20
  v=p1~choose(blank,1,2,j)
end
call verify p1~notes~items==8,'tactic observations use bounded slots'
call verify p1~outcome(first['DECISION_ID'],'SELF_CLAIMED')=='UNKNOWN_OR_EXPIRED_DECISION','expired observations cannot be retroactively altered'
say 'SLAM450 RACE TACTICS PASS' checks 'checks'
exit 0
verify:
 parse arg ok,description
 if \ok then do;say 'FAIL' description;exit 7;end
 checks+=1
return
::requires 'Slam450RaceTactics.cls'
