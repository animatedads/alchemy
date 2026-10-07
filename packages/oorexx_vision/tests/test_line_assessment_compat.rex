numeric digits 30
s=.VisionSurface~new(16,12,5,32)
/* Bright vertical band => two long vertical boundaries. */
do y=1 to 10
  s~put(6,y,31); s~put(7,y,31)
end
/* Bright horizontal band => two long horizontal boundaries. */
do x=2 to 13
  s~put(x,4,31); s~put(x,5,31)
end
r=.LineAssessment~assess(s,10,.nil,3)
call assert r~horizontalRuns~items>0,'horizontal X-runs found'
call assert r~verticalRuns~items>0,'vertical Y-runs found'
call assert r~runCount=r~horizontalRuns~items+r~verticalRuns~items,'run count contract'
do run over r~horizontalRuns
  call assert run~direction='X','horizontal direction X'
  call assert run~length>=3,'horizontal minimum run'
  call assert run~meanStrength>=10,'horizontal threshold strength'
end
do run over r~verticalRuns
  call assert run~direction='Y','vertical direction Y'
  call assert run~length>=3,'vertical minimum run'
  call assert run~meanStrength>=10,'vertical threshold strength'
end
say 'PASS Vision-backed LineAssessment compatibility runs='r~runCount
exit 0
assert: procedure
  use arg c,m
  if \c then do; say 'FAIL:' m; exit 1; end
  return
::requires 'LineAssessment.cls'
