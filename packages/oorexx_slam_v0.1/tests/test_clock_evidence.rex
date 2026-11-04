f=.HarbourClockEvidence~new
checks=0
call ok f~clockSecond('00:00:00')=0,'midnight'
call ok f~clockSecond('23:59:59')=86399,'end of day'
call ok f~clockSecond('17:23:06')-f~clockSecond('17:23:01')=5,'first displayed offset'
r=f~records
call ok r~items=4,'four observed timestamps'
d=f~compare(r)
do j=1 to 4
  call ok d[j]=5,'consistent five second display offset'
end
call ok f~qualify(r)='STABLE_DISPLAY_CLOCK_OFFSET_NOT_FRAME_SYNC','clock offset is not true time sync'
a=.array~of(r[1],r[2]);call ok f~qualify(a)='INSUFFICIENT_CLOCK_READINGS','reject too few samples'
a=.array~new
do j=1 to 4
 a~append(r[j]~copy)
end
a[4][3]='17:23:45'
call ok f~qualify(a)='VARIABLE_DISPLAY_CLOCK_OFFSET','reject variable offset'
a[4][2]='17:23:50';a[4][3]='17:23:45'
call ok f~qualify(a)='CLOCK_RATE_INCONSISTENT','reject slow clock'
say 'POWER SLAM CLOCK EVIDENCE:' checks '/' checks 'PASS'
exit 0
ok: procedure expose checks
 use arg test,label
 if \test then do
  say 'FAIL' label
  exit 1
 end
 checks+=1
 return
::requires 'SlamHarbourClockEvidence.cls'