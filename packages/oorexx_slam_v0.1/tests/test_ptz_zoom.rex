checks=0
say 'POWER SLAM PTZ ZOOM SYNTHETIC QUALIFICATION'
ref=.array~new(638);target=.array~new(638)
do x=1 to 638
 ref[x]=0
 target[x]=0
end
do x=116 to 324 by 2
 ref[x]=(x*37)//97
 dest=trunc((x-1)*1.95-102+0.5)+1
 target[dest]=ref[x]
end
r=.HarbourPtzScale~fitProfiles(ref,target,1.8,2.1,0.025,-130,-80,2)
call ok r['STATUS']='APPARENT_SCALE_CANDIDATE_UNQUALIFIED','valid synthetic match'
call ok abs(r['SCALE']-1.95)<=0.026,'scale recovered'
call ok abs(r['TRANSLATION_X_PX']+102)<=3,'translation recovered'
call ok r['CORRELATION']>0.95,'synthetic correlation'
q=.HarbourPtzScale~repeatCheck(r,r,172)
call ok q['STATUS']='REPEATED_APPARENT_ZOOM_CANDIDATE_NOT_LENS_CALIBRATED','repeat admission'
q=.HarbourPtzScale~repeatCheck(r,r,171)
call ok q['STATUS']='PTZ_ZOOM_REPEAT_NOT_PROVEN','wrong cycle rejected'
flat=.array~new(638)
do x=1 to 638
 flat[x]=10
end
q=.HarbourPtzScale~fitProfiles(flat,flat)
call ok q['STATUS']='NO_STATIONARY_TEXTURE','flat texture rejected'
call ok .HarbourPtzScale~frameBytes=230400,'raw byte size'
call ok .HarbourPtzScale~frameW=640,'raw width'
call ok .HarbourPtzScale~frameH=360,'raw height'
/* Pure translation must not be mistaken for magnification. */
pan=.array~new(638)
do x=1 to 638
 pan[x]=0
end
do x=116 to 324 by 2
 pan[x+40]=ref[x]
end
m=.HarbourPtzScale~fitProfiles(ref,pan,0.95,1.05,0.025,20,60,2)
call ok abs(m['SCALE']-1.00)<0.026,'pure pan scale stays unity'
call ok abs(m['TRANSLATION_X_PX']-40)<=3,'pure pan recovered'
/* An independent zoom with a different offset must not pass a repeat gate. */
m['TRANSLATION_X_PX']=m['TRANSLATION_X_PX']+100
q=.HarbourPtzScale~repeatCheck(r,m,172)
call ok q['STATUS']='PTZ_ZOOM_REPEAT_NOT_PROVEN','mismatched repeat blocked'
say 'PTZ SCALE TEST PASS 13 checks'
exit 0
::routine ok
 use arg truth,desc
 if \truth then do
   say 'FAIL' desc
   exit 1
 end
 return

::requires 'SlamHarbourPtzScale.cls'