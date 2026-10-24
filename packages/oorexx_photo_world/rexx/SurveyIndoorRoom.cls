/* Indoor-room survey constraints and first geometry hypothesis.
 *
 * Measurements are evidence.  A solved envelope is a hypothesis until image
 * observations and additional measurements support it.  Reusable numerical
 * solving is delegated to ooRexx Maths.
 */

::class SurveyLengthConstraint public
::attribute id get
::attribute axis get
::attribute metres get
::attribute weight get
::attribute evidenceClass get
::attribute source get
::attribute notes get
::method init
  expose id axis metres weight evidenceClass source notes
  use strict arg id,axis,metres,weight=1,evidenceClass='MEASURED',source='',notes=''
  if metres<=0 then raise syntax 88.900 array('positive metric length',metres)
  if weight<=0 then raise syntax 88.900 array('positive constraint weight',weight)
  axis=axis~upper
  select
    when axis='WIDTH' then nop
    when axis='LENGTH' then nop
    when axis='OPENING_ANCHOR' then nop
    otherwise raise syntax 88.900 array('WIDTH, LENGTH or OPENING_ANCHOR',axis)
  end
  evidenceClass=evidenceClass~upper

::class SurveyIndoorRoomHypothesis public
::attribute width get
::attribute length get
::attribute area get
::attribute openingAnchor get
::attribute remainingReferenceSpan get
::attribute confidenceClass get
::attribute basis get
::attribute constraints get
::method init
  expose width length area openingAnchor remainingReferenceSpan confidenceClass basis constraints
  use strict arg width,length,openingAnchor=.nil,constraints=.nil,basis='MANHATTAN_RECTANGLE_HYPOTHESIS'
  if constraints==.nil then constraints=.array~new
  area=width*length
  remainingReferenceSpan=.nil
  if openingAnchor<>.nil then do
    if openingAnchor>=0 then do
      if openingAnchor<=width then remainingReferenceSpan=width-openingAnchor
    end
  end
  confidenceClass='HYPOTHESIS'

::class SurveyIndoorRoomSolver public
::method solve class
  /* Weighted two-parameter least squares over WIDTH and LENGTH.  The current
   * first indoor model is intentionally a Manhattan rectangle.  Opening
   * anchors do not alter the envelope solve; they are placed on the solved
   * reference wall and retain their own evidence identity. */
  use strict arg constraints
  widthWeight=0; widthRhs=0
  lengthWeight=0; lengthRhs=0
  openingAnchor=.nil
  do c over constraints
    select
      when c~axis='WIDTH' then do
        widthWeight=widthWeight+c~weight
        widthRhs=widthRhs+c~weight*c~metres
      end
      when c~axis='LENGTH' then do
        lengthWeight=lengthWeight+c~weight
        lengthRhs=lengthRhs+c~weight*c~metres
      end
      when c~axis='OPENING_ANCHOR' then openingAnchor=c~metres
      otherwise raise syntax 88.900 array('known indoor constraint axis',c~axis)
    end
  end
  if widthWeight=0 then raise syntax 88.900 array('at least one WIDTH constraint','none')
  if lengthWeight=0 then raise syntax 88.900 array('at least one LENGTH constraint','none')
  ctx=.MathContext~decimal(30)
  h=.Maths~matrix(.array~of(.array~of(widthWeight,0),.array~of(0,lengthWeight)),ctx)
  b=.Maths~vector(.array~of(widthRhs,lengthRhs),ctx)
  x=h~solve(b)
  return .SurveyIndoorRoomHypothesis~new(x[1],x[2],openingAnchor,constraints)

::class SurveyIndoorSvg public
::method topDown class
  use strict arg room,path,title='Photo Survey World - indoor room hypothesis',scale=140,margin=70
  widthPx=room~width*scale
  lengthPx=room~length*scale
  canvasW=widthPx+2*margin
  canvasH=lengthPx+2*margin+80
  s=.array~new
  s~append('<svg xmlns="http://www.w3.org/2000/svg" width="'canvasW'" height="'canvasH'" viewBox="0 0 'canvasW' 'canvasH'">')
  s~append('<rect width="100%" height="100%" fill="white"/>')
  s~append('<text x="20" y="28" font-family="sans-serif" font-size="18">'title'</text>')
  s~append('<text x="20" y="50" font-family="sans-serif" font-size="12">HYPOTHESIS - metric anchors are evidence; unmeasured opening width remains unknown</text>')
  x0=margin; y0=margin+35
  s~append('<rect x="'x0'" y="'y0'" width="'widthPx'" height="'lengthPx'" fill="#f8f6ef" stroke="#222" stroke-width="4"/>')
  s~append('<text x="'x0+widthPx/2-35'" y="'y0-12'" font-family="sans-serif" font-size="14">'room~width' m</text>')
  s~append('<text x="'x0+widthPx+12'" y="'y0+lengthPx/2'" font-family="sans-serif" font-size="14">'room~length' m</text>')
  s~append('<text x="'x0+12'" y="'y0+30'" font-family="sans-serif" font-size="13">area 'room~area' m²</text>')
  if room~openingAnchor<>.nil then do
    ax=x0+room~openingAnchor*scale
    s~append('<line x1="'ax'" y1="'y0-12'" x2="'ax'" y2="'y0+18'" stroke="#111" stroke-width="3"/>')
    s~append('<text x="'ax-45'" y="'y0+38'" font-family="sans-serif" font-size="12">opening anchor 'room~openingAnchor' m</text>')
    if room~remainingReferenceSpan<>.nil then -
      s~append('<text x="'ax-45'" y="'y0+55'" font-family="sans-serif" font-size="12">remaining reference span 'room~remainingReferenceSpan' m</text>')
  end
  s~append('</svg>')
  self~writeLines(path,s)
  return path
::method writeLines class
  use strict arg path,lines
  call lineout path
  do line over lines
    call lineout path,line
  end
  call lineout path
  return

::requires 'MathsBootstrap.cls'

/* dev20: actual-room topology.  This does not reinterpret the user's three
 * length observations as orthogonal rectangle axes.  The old rectangle solver
 * remains available for genuinely rectangular rooms, but is not the authority
 * for this room.
 */
::class SurveyIndoorMetricObservation public
::attribute id get
::attribute role get
::attribute metres get
::attribute evidenceClass get
::attribute source get
::attribute notes get
::method init
  expose id role metres evidenceClass source notes
  use strict arg id,role,metres,evidenceClass='MEASURED',source='',notes=''
  if metres<=0 then raise syntax 88.900 array('positive metric length',metres)
  role=role~upper
  evidenceClass=evidenceClass~upper

::class SurveyWallProfileSegment public
::attribute kind get
::attribute spanMetres get
::attribute offsetMetres get
::attribute dimensionalState get
::method init
  expose kind spanMetres offsetMetres dimensionalState
  use strict arg kind,spanMetres=.nil,offsetMetres=.nil
  kind=kind~upper
  select
    when kind='LEFT_ALCOVE_REAR' then nop
    when kind='LEFT_RETURN' then nop
    when kind='CHIMNEY_BREAST_FACE' then nop
    when kind='RIGHT_RETURN' then nop
    when kind='RIGHT_ALCOVE_REAR' then nop
    otherwise raise syntax 88.900 array('known chimney-wall profile segment',kind)
  end
  if spanMetres<>.nil then if spanMetres<=0 then raise syntax 88.900 array('positive segment span',spanMetres)
  if offsetMetres<>.nil then if offsetMetres<0 then raise syntax 88.900 array('non-negative segment offset',offsetMetres)
  dimensionalState='UNRESOLVED'
  if spanMetres<>.nil then dimensionalState='PARTIAL'
  if spanMetres<>.nil then if offsetMetres<>.nil then dimensionalState='RESOLVED'

::class SurveyChimneyBreastWallTopology public
::attribute wallId get
::attribute segments get
::attribute topologyClass get
::attribute dimensionalState get
::method init
  expose wallId segments topologyClass dimensionalState
  use strict arg wallId='projector-chimney-wall'
  topologyClass='CHIMNEY_BREAST_WITH_TWO_ALCOVES'
  segments=.array~new
  segments~append(.SurveyWallProfileSegment~new('LEFT_ALCOVE_REAR'))
  segments~append(.SurveyWallProfileSegment~new('LEFT_RETURN'))
  segments~append(.SurveyWallProfileSegment~new('CHIMNEY_BREAST_FACE'))
  segments~append(.SurveyWallProfileSegment~new('RIGHT_RETURN'))
  segments~append(.SurveyWallProfileSegment~new('RIGHT_ALCOVE_REAR'))
  dimensionalState='TOPOLOGY_ONLY'
::method breastFace
  expose segments
  return segments[3]
::method hasLeftAlcove; return .true
::method hasRightAlcove; return .true
::method isDimensionallyResolved; return .false

::class SurveyIndoorActualRoomHypothesis public
::attribute metricObservations get
::attribute chimneyWall get
::attribute topologyClass get
::attribute area get
::attribute areaState get
::attribute confidenceClass get
::method init
  expose metricObservations chimneyWall topologyClass area areaState confidenceClass
  use strict arg metricObservations,chimneyWall
  if \chimneyWall~isA(.SurveyChimneyBreastWallTopology) then -
    raise syntax 88.900 array('SurveyChimneyBreastWallTopology',chimneyWall~class~id)
  topologyClass='CHIMNEY_BREAST_WITH_TWO_ALCOVES'
  area=.nil
  areaState='UNRESOLVED_TOPOLOGY_DIMENSIONS'
  confidenceClass='TOPOLOGY_CONFIRMED_DIMENSIONS_PARTIAL'
::method observation
  expose metricObservations
  use strict arg id
  do o over metricObservations
    if o~id=id then return o
  end
  return .nil
::method canComputeArea; return .false

::class SurveyIndoorActualRoomSolver public
::method fromCurrentEvidence class
  observations=.array~new
  observations~append(.SurveyIndoorMetricObservation~new('left-wall-to-doorway','LEFT_WALL_TO_DOORWAY','2.750','MEASURED','user measurement','endpoint wording retained; not reinterpreted as rectangle width'))
  observations~append(.SurveyIndoorMetricObservation~new('opposite-wall','OPPOSITE_WALL','3.750','MEASURED','user measurement','wall span; geometry binding remains explicit evidence'))
  observations~append(.SurveyIndoorMetricObservation~new('long-wall','LONG_WALL','5.000','ESTIMATED','user estimate','approximately five metres'))
  wall=.SurveyChimneyBreastWallTopology~new('projector-screen-chimney-wall')
  return .SurveyIndoorActualRoomHypothesis~new(observations,wall)

::class SurveyIndoorTopologySvg public
::method topDown class
  use strict arg room,path,title='Photo Survey World - actual room topology'
  if \room~isA(.SurveyIndoorActualRoomHypothesis) then -
    raise syntax 88.900 array('SurveyIndoorActualRoomHypothesis',room~class~id)
  s=.array~new
  w=900; h=610
  s~append('<svg xmlns="http://www.w3.org/2000/svg" width="'w'" height="'h'" viewBox="0 0 'w' 'h'">')
  s~append('<rect width="100%" height="100%" fill="white"/>')
  s~append('<text x="30" y="34" font-family="sans-serif" font-size="20">'title'</text>')
  s~append('<text x="30" y="60" font-family="sans-serif" font-size="13">TOPOLOGY CONFIRMED; chimney/alcove dimensions unresolved - schematic, not to scale</text>')
  /* opposite straight wall */
  x0=120; x1=780; yTop=130; yRear=455; yBreast=395
  s~append('<line x1="'x0'" y1="'yTop'" x2="'x1'" y2="'yTop'" stroke="#222" stroke-width="5"/>')
  s~append('<text x="365" y="112" font-family="sans-serif" font-size="14">long-wall prior ~5.000 m</text>')
  /* side walls */
  s~append('<line x1="'x0'" y1="'yTop'" x2="'x0'" y2="'yRear'" stroke="#222" stroke-width="5"/>')
  s~append('<line x1="'x1'" y1="'yTop'" x2="'x1'" y2="'yRear'" stroke="#222" stroke-width="5"/>')
  /* rear alcove plane -> left return -> projecting breast face -> right return -> rear alcove plane */
  leftBreak=315; rightBreak=585
  s~append('<line x1="'x0'" y1="'yRear'" x2="'leftBreak'" y2="'yRear'" stroke="#222" stroke-width="5"/>')
  s~append('<line x1="'leftBreak'" y1="'yRear'" x2="'leftBreak'" y2="'yBreast'" stroke="#222" stroke-width="5"/>')
  s~append('<line x1="'leftBreak'" y1="'yBreast'" x2="'rightBreak'" y2="'yBreast'" stroke="#222" stroke-width="7"/>')
  s~append('<line x1="'rightBreak'" y1="'yBreast'" x2="'rightBreak'" y2="'yRear'" stroke="#222" stroke-width="5"/>')
  s~append('<line x1="'rightBreak'" y1="'yRear'" x2="'x1'" y2="'yRear'" stroke="#222" stroke-width="5"/>')
  s~append('<text x="170" y="485" font-family="sans-serif" font-size="14">left alcove / inset</text>')
  s~append('<text x="362" y="377" font-family="sans-serif" font-size="14">old chimney breast</text>')
  s~append('<text x="357" y="414" font-family="sans-serif" font-size="13">projector screen face</text>')
  s~append('<text x="612" y="485" font-family="sans-serif" font-size="14">right alcove / inset</text>')
  s~append('<text x="30" y="535" font-family="sans-serif" font-size="13">Measured evidence retained without remapping: left wall to doorway 2.750 m; opposite wall 3.750 m.</text>')
  s~append('<text x="30" y="560" font-family="sans-serif" font-size="13">Unknown: breast width, breast projection depth, left/right alcove widths, exact doorway/jamb binding. Area deliberately not computed.</text>')
  s~append('</svg>')
  self~writeLines(path,s)
  return path
::method writeLines class
  use strict arg path,lines
  call lineout path
  do line over lines
    call lineout path,line
  end
  call lineout path
  return
