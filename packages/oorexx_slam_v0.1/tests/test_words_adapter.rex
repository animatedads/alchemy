parse arg filename
if filename='' then filename='/mnt/data/harbour_heights.words'
t=.HarbourWordsMGA~new(filename)
checks=0
call assert t~columns=226,'columns'
call assert t~rows=204,'rows'
call assert t~resolution=50,'spacing'
call assert t~datum='AHD71','vertical datum'
a=t~sampleMGA(330586.9,6259261.5)
call assert a['STATUS']='HEIGHT_AHD71','first sample status'
call assert a['HEIGHT_M']=68.8,'first sample elevation'
b=t~sampleMGA(330586.9+50,6259261.5)
call assert b['HEIGHT_M']=71.7,'adjacent east'
c=t~sampleMGA(330586.9,6259261.5-50)
call assert c['HEIGHT_M']=68.6,'adjacent south'
d=t~sampleMGA(0,0)
call assert d['STATUS']='UNKNOWN_OUTSIDE_GRID','outside coverage'
e=t~sampleLocal(50,0,330586.9,6259261.5)
call assert e['HEIGHT_M']=71.7,'explicit local origin'
call assert e['ROLE']='UNCLASSIFIED','no height-as-water conflation'
f=t~sampleMGA(330586.9-100,6259261.5)
call assert f['STATUS']='UNKNOWN_OUTSIDE_GRID','west of grid'
g=t~sampleMGA(330586.9,6259261.5+100)
call assert g['STATUS']='UNKNOWN_OUTSIDE_GRID','north of grid'
h=t~sampleMGA(330586.9+226*50,6259261.5)
call assert h['STATUS']='UNKNOWN_OUTSIDE_GRID','east of grid'
i=t~sampleMGA(330586.9,6259261.5-204*50)
call assert i['STATUS']='UNKNOWN_OUTSIDE_GRID','south of grid'
say 'PASS' checks 'native tests'
exit 0
assert:
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  checks=checks+1
  return

::requires "SlamHarbourWordsAdapter.cls"
