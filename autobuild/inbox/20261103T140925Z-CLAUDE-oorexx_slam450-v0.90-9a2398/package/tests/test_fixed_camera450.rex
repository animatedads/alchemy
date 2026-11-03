/* Native qualification: camera gate cannot be bypassed via camera rotation,
 * parallel selection or repeated sensor calls in one navigation turn. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
w=.Slam450World~new(45042)
n=.Slam450FixedCameraNetwork~new(w)
checks=0
r=n~request('CAFE_SYDNEY')
call verify r['STATUS']='DENIED','startup denied'
r=n~request('INVALID_CAMERA')
call verify r['STATUS']='DENIED','unknown camera denied'
do i=1 to 4
  call verify w~step(0,0.5,0)='RUNNING','flight progression'
end
r=n~request('BLUES_PT')
call verify r['STATUS']='DENIED','before step five denied'
call verify w~step(0,0.5,0)='RUNNING','fifth flight step'
r=n~request('CAFE_SYDNEY')
call verify r['STATUS']='GRANTED','first grant at step five'
call verify r['CAMERA']='CAFE_SYDNEY','one fixed site'
call verify r['FRAME']~hasIndex('PIXELS'),'frame image supplied'
call verify \r['FRAME']~hasIndex('POSE'),'no pose in feed'
call verify \r['FRAME']~hasIndex('WORLD'),'no world leakage in feed'
r=n~request('BLUES_PT')
call verify r['STATUS']='DENIED','no second simultaneous feed'
do i=1 to 4
  call verify w~step(0,0.5,0)='RUNNING','forward between grants'
end
r=n~request('KIRRIBILLI')
call verify r['STATUS']='DENIED','four steps not five'
call verify w~step(0,0.5,0)='RUNNING','tenth step'
r=n~request('BLUES_PT')
call verify r['STATUS']='GRANTED','second grant at step ten'
call verify n~grantCount=2,'two grants exactly'
call verify n~denyCount=5,'denials exact'
say 'SLAM450 CAMERA NETWORK PASS' checks 'checks'
exit 0
verify:
  parse arg pass,message
  if \pass then do
    say 'FAIL' message;exit 8
  end
  checks+=1
return

::requires 'Slam450Flight.cls'
