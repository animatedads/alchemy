/* ooRexx Vision Line Assessment compatibility v0.1-dev1
 * API compatibility seam: LineAssessment.assess(surface, threshold, valueModel, minimumRun)
 *
 * Purpose:
 *   Preserve the LineAssessment evidence shape consumed by Vision 3D dev10,
 *   while deriving frame-local structural runs directly from the current
 *   vision/0.1 value-distance contract.  This is an adapter, not a new scene
 *   classifier and not persistent object identity authority.
 */

::class LineAssessmentRun public
::method init
  expose direction startX startY endX endY length meanStrength evidenceKind
  use strict arg direction,startX,startY,endX,endY,length,meanStrength,evidenceKind='VISION_BOUNDARY_DISTANCE'
  direction=direction~upper
  if \(direction='X' | direction='Y') then raise syntax 40.900 array('LineAssessmentRun direction must be X or Y')
  if length<1 then raise syntax 40.900 array('LineAssessmentRun length must be positive')
::attribute direction get
::attribute startX get
::attribute startY get
::attribute endX get
::attribute endY get
::attribute length get
::attribute meanStrength get
::attribute evidenceKind get

::class LineAssessmentResult public
::method init
  expose horizontalRuns verticalRuns threshold minimumRun evidenceKind
  use strict arg horizontalRuns,verticalRuns,threshold,minimumRun,evidenceKind='VISION_BOUNDARY_DISTANCE'
::attribute horizontalRuns get
::attribute verticalRuns get
::attribute threshold get
::attribute minimumRun get
::attribute evidenceKind get
::method runCount
  expose horizontalRuns verticalRuns
  return horizontalRuns~items+verticalRuns~items

::class LineAssessment public
::method assess class
  use strict arg surface,threshold=1,valueModel=.nil,minimumRun=3
  if threshold<0 then raise syntax 40.900 array('LineAssessment threshold must be non-negative')
  if minimumRun<1 then raise syntax 40.900 array('LineAssessment minimumRun must be positive')
  if valueModel==.nil then do
    valueModel=surface~valueModel
    if valueModel==.nil then valueModel=.VisionValueModel~new(surface~valueCount)
  end

  horizontal=.array~new
  vertical=.array~new

  /* Horizontal X-runs are consecutive vertical-neighbour boundaries.  The
   * geometric y coordinate is the half-cell boundary between the two rows. */
  if surface~height>1 then do y=0 to surface~height-2
    active=.false; start=0; count=0; strength=0
    do x=0 to surface~width-1
      d=valueModel~distance(surface~at(x,y),surface~at(x,y+1))
      if d>=threshold then do
        if \active then do; active=.true; start=x; count=0; strength=0; end
        count=count+1; strength=strength+d
      end
      else if active then do
        if count>=minimumRun then horizontal~append(.LineAssessmentRun~new('X',start,y+.5,x-1,y+.5,count,strength/count))
        active=.false; count=0; strength=0
      end
    end
    if active then do
      if count>=minimumRun then horizontal~append(.LineAssessmentRun~new('X',start,y+.5,surface~width-1,y+.5,count,strength/count))
    end
  end

  /* Vertical Y-runs are consecutive horizontal-neighbour boundaries.  The
   * geometric x coordinate is the half-cell boundary between the columns. */
  if surface~width>1 then do x=0 to surface~width-2
    active=.false; start=0; count=0; strength=0
    do y=0 to surface~height-1
      d=valueModel~distance(surface~at(x,y),surface~at(x+1,y))
      if d>=threshold then do
        if \active then do; active=.true; start=y; count=0; strength=0; end
        count=count+1; strength=strength+d
      end
      else if active then do
        if count>=minimumRun then vertical~append(.LineAssessmentRun~new('Y',x+.5,start,x+.5,y-1,count,strength/count))
        active=.false; count=0; strength=0
      end
    end
    if active then do
      if count>=minimumRun then vertical~append(.LineAssessmentRun~new('Y',x+.5,start,x+.5,surface~height-1,count,strength/count))
    end
  end

  return .LineAssessmentResult~new(horizontal,vertical,threshold,minimumRun)

::requires 'Vision.cls'
