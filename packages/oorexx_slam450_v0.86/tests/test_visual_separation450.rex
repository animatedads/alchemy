numeric digits 16
checks=0
f=.directory~new;f['WIDTH']=480;f['HEIGHT']=121
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
/* P is a nearby craft 55 degrees to starboard. */
 do i=55 to 67;rows[i]=overlay('P'~copies(41),rows[i],285);end
f['PIXELS']=rows
sep=.Slam450VisualSeparation~new
cmd=.array~of(0,6,0)
result=sep~adjust('A1',f,cmd)
call check result[2]==0 & result[4]==-3,'large P silhouette must trigger port evasive control'
/* R to port: evade starboard. */
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
 do i=55 to 67;rows[i]=overlay('R'~copies(41),rows[i],145);end
f['PIXELS']=rows
result=sep~adjust('A3',f,cmd)
call check result[2]==0 & result[4]==3,'large R silhouette must trigger starboard evasive control'
/* Tiny or astern silhouettes must not control flight. */
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
rows[61]=overlay('P'~copies(3),rows[61],250)
f['PIXELS']=rows
result=sep~adjust('A1',f,cmd)
call check result~items==3 & result[2]==6,'distant silhouette does not disrupt own pilot'
say 'VISUAL SEPARATION PASS' checks
exit 0
check:
  parse arg yes,label
  if \yes then do;say 'FAIL:' label;exit 9;end
  checks+=1
  say 'PASS:' label
return
::requires 'Slam450VisualSeparation.cls'
