numeric digits 16
checks=0
pilot=.Slam450Pilot~new
f=.directory~new;f['WIDTH']=480;f['HEIGHT']=121
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
/* Large nearby target above the aircraft centreline. */
 do i=16 to 54;rows[i]=overlay('2'~copies(51),rows[i],215);end
f['PIXELS']=rows
c=pilot~control(f,2)
call verify c[3]>0 & c[3]<=0.7,'near above target damped climb'
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
 do i=70 to 108;rows[i]=overlay('2'~copies(51),rows[i],215);end
f['PIXELS']=rows
c=pilot~control(f,2)
call verify c[3]<0 & c[3]>=-0.7,'near below target damped descent'
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
rows[27]=overlay('2'~copies(3),rows[27],239)
f['PIXELS']=rows
c=pilot~control(f,2)
call verify c[3]>1.2,'distant target permits larger climb'
/* Stagnant near target image causes stronger bounded forward action. */
rows=.array~new
 do i=1 to 121;rows~append('.'~copies(480));end
 do i=43 to 79;rows[i]=overlay('2'~copies(41),rows[i],220);end
f['PIXELS']=rows
pilot=.Slam450Pilot~new
first=pilot~control(f,2)
second=pilot~control(f,2)
say 'NEAR_DIAGNOSTIC' first[1] first[2] first[3] second[1] second[2] second[3]
call verify first[2]<3 & second[2]=3,'near centred stagnant target prompts forward pulse'
say 'PRECISION CONTROLLER PASS' checks
exit 0
verify:
  parse arg yes,label
  if \yes then do;say 'FAIL' label;exit 7;end
  checks+=1;say 'PASS' label
return
::requires 'Slam450Flight.cls'
