/* Power SLAM: qualify REAL ooRexx 360-degree SVG geometry, not illustration.
 * Architecture Tom Dyer. Test and renderer ChatGPT GPT-6, 2026-11-01.
 * Run: rexx test_harbour_panorama.rex OUTPUT_DIRECTORY
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dest
if dest=='' then dest='.'
p=.HarbourPanorama~new
checks=0
call check p~scene~boxes~items=7,'model: 4 pylons, deck, opera, tower'
call check p~scene~features['T'][3]=263,'Salesforce roof is 263m ASL in this model'
do key over .array~of('KIRRIBILLI','CIRCULAR','BLUES')
  cam=p~siteCamera(key)
  call check cam[3]=50,key 'camera z = 50m ASL'
  file=dest || '/' || key~lower || '_model_360.svg'
  p~render(key,file)
  call check stream(file,'C','QUERY EXISTS')\=='',key 'written'
  data=charin(file,1,chars(file));call stream file,'C','CLOSE'
  call check data~left(4)=='<svg',key 'root SVG opens'
  call check data~strip('T','0a'x)~right(6)=='</svg>',key 'root SVG closes at EOF'
  call check lastpos('<polygon ',data)<lastpos('</svg>',data),key 'all geometry before closing tag'
  call check occurrences(data,'<polygon ')=126,key 'all 42 cuboid faces * 3 panorama wraps'
  call check data~caselessPos('Salesforce 263m')>0,key 'tower annotation present'
  call check data~caselessPos('Opera box')>0,key 'opera annotation present'
  call check data~caselessPos('Bridge N')>0 & data~caselessPos('Bridge S')>0,key 'both bridge annotations present'
  call check p~bearing(1,0)=90,key 'east = 90 degrees'
end
n=p~pointAngles(p~scene~features['N'],p~siteCamera('KIRRIBILLI'))
s=p~pointAngles(p~scene~features['S'],p~siteCamera('KIRRIBILLI'))
o=p~pointAngles(p~scene~features['O'],p~siteCamera('KIRRIBILLI'))
t=p~pointAngles(p~scene~features['T'],p~siteCamera('KIRRIBILLI'))
call check n[1]>s[1] & s[1]>o[1],'Kirribilli: bridge N, bridge S, Opera bearing order'
call check t[1]>o[1] & t[1]<s[1],'Kirribilli: Salesforce bearing between Opera and bridge S'
n=p~pointAngles(p~scene~features['N'],p~siteCamera('BLUES'))
s=p~pointAngles(p~scene~features['S'],p~siteCamera('BLUES'))
o=p~pointAngles(p~scene~features['O'],p~siteCamera('BLUES'))
call check n[1]<o[1] & o[1]<s[1],'Blues: Opera bearing between bridge N and S'
n=p~pointAngles(p~scene~features['N'],p~siteCamera('CIRCULAR'))
s=p~pointAngles(p~scene~features['S'],p~siteCamera('CIRCULAR'))
o=p~pointAngles(p~scene~features['O'],p~siteCamera('CIRCULAR'))
call check s[1]>340 & n[1]<20 & o[1]>20 & o[1]<55,'Circular: bridge straddles 0/360; Opera NE'
say 'POWER SLAM PANORAMA SVG QUALIFICATION: PASS (' || checks || ' checks)'
exit 0
occurrences: procedure
  use arg txt,needle
  k=0
  do forever
    at=pos(needle,txt)
    if at=0 then leave
    k+=1
    txt=txt~substr(at+needle~length)
  end
  return k
check: procedure expose checks
  use arg conditionValue,label
  checks+=1
  if conditionValue then say 'PASS' label
  else do
    say 'FAIL' label
    exit 1
  end
  return
::requires 'SlamHarbourPanorama.cls'
