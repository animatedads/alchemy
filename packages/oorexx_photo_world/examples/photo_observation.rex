spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
cam=.SurveyCamera~new('PAISLEY-01',.SurveyPose~new,1.60,60,1,1,spec,'MAIN')
cam~moveTo(0,0,1.60)~setAngles(18,-3,0)
photo=.SurveyPhotoObservation~new('IMG-001',3024,4032,cam,.nil,.SurveyImageProcessing~new(.nil,.false,.nil,.nil,.nil,.nil,'PORTRAIT'),,'main lens hypothesis',0.8)
say photo~id 'camera='spec~model 'lens='photo~lensSpecification~id
say 'camera height prior='photo~cameraHeightPrior
say 'effective image='photo~effectiveWidth'x'photo~effectiveHeight
say 'derived FOV X/Y='photo~nominalFovX photo~nominalFovY
::requires '../rexx/PhotoObservation.cls'
