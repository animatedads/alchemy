parse source . . here
root=filespec('location',here)'..'; call directory root
m=.SurveyAreaMap~new('t')
m~addNode(.SurveyMapNode~new('A',0,0,'ANCHOR','A','OBSERVED',1))
p=.SurveyMapPath~new('P','road'); p~add(0,0); p~add(10,10); m~addPath(p)
if m~nodes~items<>1 then exit 1
if m~paths~items<>1 then exit 2
say 'PASS area map model'; exit 0
::requires '../rexx/SurveyAreaMap.cls'
