parse source . . here
root=filespec('location',here)'..'; call directory root
/* Synthetic qualification: known similarity x2, +90 degrees, translation (10,-5). */
a=.array~new
a~append(.SurveyControlPoint~new('A',0,0,10,-5))
a~append(.SurveyControlPoint~new('B',10,0,10,15))
a~append(.SurveyControlPoint~new('C',0,10,-10,-5))
a~append(.SurveyControlPoint~new('D',10,10,-10,15))
t=.SurveyRegistration2D~solveSimilarity(a)
if abs(t~scale-2)>0.0000001 then exit 1
if abs(t~cos)>0.0000001 then exit 2
if abs(t~sin-1)>0.0000001 then exit 3
if t~rms>0.0000001 then exit 4
parse value t~map(5,5) with x ',' y
if abs(x-0)>0.0000001 | abs(y-5)>0.0000001 then exit 5
say 'PASS explicit-control similarity registration'; exit 0
::requires '../rexx/SurveyRegistration.cls'
