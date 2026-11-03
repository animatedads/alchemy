/* Postflight recovery of image-only arrival signatures from the sealed truth
 * log. Uses geometry ONLY in the after-flight recorder, not in SLAM pilot.
 * Matching prior navigation image uses the pose at the BEFORE-arrival frame.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg truthFile output seed mode
if seed=='' then seed=45042
if mode=='' then mode='LOOP'
world=.Slam450World~new(seed,mode)
cam=.Slam450Camera~new(world)
mem=.Slam450VisualMemory~new
header=linein(truthFile)
old=.array~of(270,-610,65,230)
stage=1
pins=0
do while lines(truthFile)>0
 rec=linein(truthFile)
 if rec=='' then iterate
 parse var rec step ',' x ',' y ',' z ',' yaw ',' active ',' other
 if \datatype(step,'W') then iterate
 if datatype(active,'W') & active>stage then do
   f=cam~renderAt(old,720,181)
   result=mem~pinFrame(f,step,stage)
   say 'REPLAY_PIN' stage 'STEP' step result
   pins+=1
   stage=active
 end
 old=.array~of(x,y,z,yaw)
end
call stream truthFile,'C','CLOSE'
if pins\=5 then do;say 'FAIL PIN COUNT' pins;exit 7;end
number=mem~savePinned(output)
s1=mem~pins['T1']['SIGNATURE']
s5=mem~pins['T5']['SIGNATURE']
score=mem~similarity(s1,s5)
say 'REPLAY_PIN SCORE QUAY_FIRST_VS_RETURN' score 'PIN_COUNT' number
exit 0
::requires 'Slam450Learning.cls'
