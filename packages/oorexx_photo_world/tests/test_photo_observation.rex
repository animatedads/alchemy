spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
pose=.SurveyPose~new
cam=.SurveyCamera~new('C1',pose,1.60,60,1,1,spec,'MAIN')
proc=.SurveyImageProcessing~new(.nil,.false,.nil,.nil,.nil,.nil,'PORTRAIT',.nil,'ISP state unknown')
photo=.SurveyPhotoObservation~new('P1',3024,4032,cam,.nil,proc,'field photo','XCover Pro main hypothesis',0.8)
if photo~cameraHeightPrior<>1.60 then exit 20
if cam~imageWidth<>3024 | cam~imageHeight<>4032 then exit 21
uncroppedWithCropMetadata=.SurveyImageProcessing~new(.nil,.false,0,0,111,222,'PORTRAIT')
if uncroppedWithCropMetadata~effectiveWidth(3024)<>3024 then exit 24
if uncroppedWithCropMetadata~effectiveHeight(4032)<>4032 then exit 25
cropped=.SurveyImageProcessing~new(.nil,.true,10,20,111,222,'PORTRAIT')
if cropped~effectiveWidth(3024)<>111 then exit 26
if cropped~effectiveHeight(4032)<>222 then exit 27
if photo~lensSpecification~id<>'MAIN' then exit 22
cam~setAngles(12,-4,1)
if cam~pose~pitch<>-4 then exit 23
say 'PASS photo observation'
::requires '../rexx/PhotoObservation.cls'
