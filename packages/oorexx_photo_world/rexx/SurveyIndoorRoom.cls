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
