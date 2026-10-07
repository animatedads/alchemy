/* Current indoor-survey metric anchors.  This example intentionally renders
 * only geometry established by the supplied measurements / explicit prior.
 * Photographic structure remains evidence and is not drawn as truth. */
parse arg outputPath
if outputPath='' then outputPath='../output/indoor_room_plan.svg'
constraints=.array~new
constraints~append(.SurveyLengthConstraint~new('opposite-wall','WIDTH','3.750',1000,'MEASURED','user measurement'))
constraints~append(.SurveyLengthConstraint~new('long-wall','LENGTH','5.000',4,'ESTIMATED','user estimate'))
constraints~append(.SurveyLengthConstraint~new('left-to-doorway','OPENING_ANCHOR','2.750',1000,'MEASURED','user measurement'))
room=.SurveyIndoorRoomSolver~solve(constraints)
written=.SurveyIndoorSvg~topDown(room,outputPath,'Indoor room - measured first hypothesis')
say 'width='room~width 'length='room~length 'area='room~area
say 'opening-anchor='room~openingAnchor 'remaining-reference-span='room~remainingReferenceSpan
say 'wrote' outputPath
::requires '../rexx/SurveyIndoorRoom.cls'
