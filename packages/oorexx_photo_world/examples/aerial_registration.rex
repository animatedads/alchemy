/* Registration API example. Coordinates are deliberately synthetic.
   Replace them with explicitly measured common points from supplied evidence frames. */
parse source . . here
root=filespec('location',here)'..'; call directory root
f=.SurveyEvidenceFrame~new('aerial-example',1152,1536)
f~addControl(.SurveyControlPoint~new('corner-A',100,200,0,0,1,'MANUAL',3))
f~addControl(.SurveyControlPoint~new('corner-B',500,200,100,0,1,'MANUAL',3))
f~addControl(.SurveyControlPoint~new('corner-C',100,600,0,-100,1,'MANUAL',3))
t=f~solve
say 'scale='t~scale 'rms='t~rms 'controls='t~count
say 'pixel 300,400 -> world 'f~mapPoint(300,400)
::requires 'rexx/SurveyRegistration.cls'
