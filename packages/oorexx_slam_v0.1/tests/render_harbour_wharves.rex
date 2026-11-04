/* Run: rexx render_harbour_wharves.rex OUTPUT_DIRECTORY */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dest
if dest=='' then dest='.'
p=.HarbourWharfPanorama~new
do key over .array~of('KIRRIBILLI','CIRCULAR','BLUES')
  file=dest || '/' || key~lower || '_wharves_360.svg'
  p~render(key,file)
  say key 'rendered:' file 'boxes:' p~scene~boxes~items
  do id over .array~of('CQ2','CQ3','CQ4','CQ5','CQ6','WB23','WB45','WB67','WB89')
    say key id 'bearing' format(p~bearingOf(id,key),3,2)
  end
end
say 'POWER SLAM V0.4 WHARF RENDER: PASS'
exit 0
::requires 'SlamHarbourWharves.cls'

