parse arg path digest
if path="" then do; say "SKIP test_real_media (set MVTRES_350 or pass path)"; exit 0; end
if digest="" then digest="UNVERIFIED"
m=.IBM370CCKDMedia~new(path,"MVTRES",digest)
say 'GEOM' m~cylinders m~heads m~trackSize d2x(m~deviceType,2)
a=m~records(0,0)
say 'RECORDS' a~items
do r over a
  say r~record r~keyLength r~dataLength r~idHex r~dataHex~left(64)
end
if a~items<>5 then raise syntax 40.900 array('expected 5 track-zero records')
if a[3]~dataHex~left(16)<>"07003AB840000006" then raise syntax 40.900 array('unexpected MVT IPL record')
say 'PASS test_real_media'
::requires "IBM370Media.cls"
