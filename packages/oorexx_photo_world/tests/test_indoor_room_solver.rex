constraints=.array~new
constraints~append(.SurveyLengthConstraint~new('opposite-wall','WIDTH','3.750',1000,'MEASURED','user measurement','opposite wall'))
constraints~append(.SurveyLengthConstraint~new('long-wall','LENGTH','5.000',4,'ESTIMATED','user estimate','long wall say 5 metres'))
constraints~append(.SurveyLengthConstraint~new('left-to-doorway','OPENING_ANCHOR','2.750',1000,'MEASURED','user measurement','endpoint semantics retained as opening anchor'))
room=.SurveyIndoorRoomSolver~solve(constraints)
if room~width<>3.750 then raise syntax 93.900 array('indoor width solve failed',room~width)
if room~length<>5.000 then raise syntax 93.900 array('indoor length solve failed',room~length)
if room~area<>18.75 then raise syntax 93.900 array('indoor area failed',room~area)
if room~openingAnchor<>2.750 then raise syntax 93.900 array('opening anchor failed',room~openingAnchor)
if room~remainingReferenceSpan<>1.000 then raise syntax 93.900 array('remaining reference span failed',room~remainingReferenceSpan)
say 'PASS indoor measured-room hypothesis through Maths solve'
return 'INDOOR-ROOM-SOLVER-PASS'
::requires '../rexx/SurveyIndoorRoom.cls'
