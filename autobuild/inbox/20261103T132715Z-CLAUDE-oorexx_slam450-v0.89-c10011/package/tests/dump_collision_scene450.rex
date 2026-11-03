/* Independent geometric source receipt: raw PowerSLAM vertices only.
 * Not available to onboard pilot or the five fixed image clients. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outfile seed mode
if outfile=='' then outfile='scene_oracle.csv'
if seed=='' then seed=45042
if mode=='' then mode='LEGACY'
w=.Slam450World~new(seed,mode)
call lineout outfile,'name,v1x,v1y,v1z,v2x,v2y,v2z,v3x,v3y,v3z,v5x,v5y,v5z'
do b over w~scene~boxes
 v=b[2]
 t=b[1]
 do i over .array~of(1,2,3,5)
  p=v[i]
  do j=1 to 3
   t=t||','||p[j]
  end
 end
 call lineout outfile,t
end
call stream outfile,'C','CLOSE'
say 'SLAM450 POWER_SLAM_V040_MODEL_BOXES' w~scene~boxes~items
::requires 'Slam450Flight.cls'
