/* Photo Survey World image-geometry evidence.
 *
 * Python/provider code may detect 2-D primitives, but it does not solve world
 * geometry.  This package receives explicit image segments as ordinary ooRexx
 * objects and performs vanishing-point / Manhattan checks through ooRexx Maths.
 */

::class SurveyImageSegment public
::attribute id get
::attribute x1 get
::attribute y1 get
::attribute x2 get
::attribute y2 get
::attribute length get
::attribute angleDegrees get
::attribute providerFamily get
::attribute midX get
::attribute midY get
::attribute lineA get
::attribute lineB get
::attribute lineC get
::method init
  expose id x1 y1 x2 y2 length angleDegrees providerFamily midX midY lineA lineB lineC
  use strict arg id,x1,y1,x2,y2,providerFamily='UNCLASSIFIED',ctx=.nil
  if ctx==.nil then ctx=.MathContext~decimal(30)
  dx=x2-x1; dy=y2-y1
  length=.Maths~sqrt(dx*dx+dy*dy,ctx)
  if length=0 then raise syntax 88.900 array('non-zero image segment length',length)
  angleDegrees=.Maths~atan2(dy,dx,ctx)~degreesValue
  do while angleDegrees<0; angleDegrees=angleDegrees+180; end
  do while angleDegrees>=180; angleDegrees=angleDegrees-180; end
  providerFamily=providerFamily~upper
  midX=(x1+x2)/2; midY=(y1+y2)/2
  /* Homogeneous image line through p1,p2, normalized so sqrt(a^2+b^2)=1. */
  rawA=y1-y2; rawB=x2-x1; rawC=x1*y2-x2*y1
  norm=.Maths~sqrt(rawA*rawA+rawB*rawB,ctx)
  lineA=rawA/norm; lineB=rawB/norm; lineC=rawC/norm
::method dx; expose x1 x2; return x2-x1
::method dy; expose y1 y2; return y2-y1
::method perpendicularDistance
  expose lineA lineB lineC
  use strict arg x,y
  return (lineA*x+lineB*y+lineC)~abs

::class SurveyImageSegmentCollection public
::attribute sourceId get
::attribute sourceRef get
::attribute imageWidth get
::attribute imageHeight get
::attribute segments get
::attribute context get
::method init
  expose sourceId sourceRef imageWidth imageHeight segments context
  use strict arg sourceId='',sourceRef='',imageWidth=0,imageHeight=0,context=.nil
  if context==.nil then context=.MathContext~decimal(30)
  segments=.array~new
::method setImageSize
  expose imageWidth imageHeight
  use strict arg width,height
  if width<=0 then raise syntax 88.900 array('positive image width',width)
  if height<=0 then raise syntax 88.900 array('positive image height',height)
  imageWidth=width; imageHeight=height
  return self
::method appendSegment
  expose segments context
  use strict arg x1,y1,x2,y2,providerFamily='UNCLASSIFIED'
  id='seg-'||(segments~items+1)
  segment=.SurveyImageSegment~new(id,x1,y1,x2,y2,providerFamily,context)
  segments~append(segment)
  return segments~items
::method count; expose segments; return segments~items
::method at; expose segments; use strict arg index; return segments[index]

::class SurveyVanishingPoint public
::attribute x get
::attribute y get
::attribute inliers get
::attribute rmsPixels get
::attribute weight get
::attribute context get
::method init
  expose x y inliers rmsPixels weight context
  use strict arg x,y,inliers,rmsPixels,weight,context
::method inlierCount; expose inliers; return inliers~items
::method contains
  expose inliers
  use strict arg segment
  do candidate over inliers
    if candidate==segment then return .true
  end
  return .false

::class SurveyVanishingSolution public
::attribute points get
::attribute sourceSegmentCount get
::attribute unresolvedSegmentCount get
::attribute angleToleranceDegrees get
::attribute context get
::method init
  expose points sourceSegmentCount unresolvedSegmentCount angleToleranceDegrees context
  use strict arg points,sourceSegmentCount,unresolvedSegmentCount,angleToleranceDegrees,context
::method pointCount; expose points; return points~items
::method nearestTo
  expose points context
  use strict arg x,y
  best=.nil; bestDistance=.nil
  do point over points
    dx=point~x-x; dy=point~y-y
    d=.Maths~sqrt(dx*dx+dy*dy,context)
    if best==.nil then do; best=point; bestDistance=d; end
    else if d<bestDistance then do; best=point; bestDistance=d; end
  end
  return best
::method familyIndexFor
  expose points
  use strict arg segment
  do i=1 to points~items
    if points[i]~contains(segment) then return i
  end
  return 0

::class SurveyVanishingPointSolver public
::method solve class
  use strict arg collection,maxPoints=3,angleToleranceDegrees='3.0',minInliers=3
  if \collection~isA(.SurveyImageSegmentCollection) then -
    raise syntax 88.900 array('SurveyImageSegmentCollection',collection~class~id)
  ctx=collection~context
  toleranceRadians=.MathAngle~degrees(angleToleranceDegrees,ctx)~radiansValue
  tanTolerance=.Maths~tan(toleranceRadians,ctx)
  available=collection~segments~copy
  points=.array~new
  do while points~items<maxPoints
    if available~items<minInliers then leave
    seed=self~bestSeed(available,tanTolerance,ctx)
    if seed==.nil then leave
    refined=self~refine(seed[1],seed[2],available,tanTolerance,ctx)
    if refined==.nil then leave
    if refined~inlierCount<minInliers then leave
    points~append(refined)
    remaining=.array~new
    do segment over available
      if \refined~contains(segment) then remaining~append(segment)
    end
    available=remaining
  end
  return .SurveyVanishingSolution~new(points,collection~count,available~items,angleToleranceDegrees,ctx)

::method bestSeed class
  use strict arg segments,tanTolerance,ctx
  best=.nil; bestWeight=-1; bestCount=-1
  do first over segments
    do second over segments
      if first==second then iterate
      determinant=first~lineA*second~lineB-second~lineA*first~lineB
      if determinant~abs<'0.000000001' then iterate
      x=(first~lineB*second~lineC-second~lineB*first~lineC)/determinant
      y=(first~lineC*second~lineA-second~lineC*first~lineA)/determinant
      scored=self~scoreCandidate(x,y,segments,tanTolerance)
      if scored[2]>bestWeight then do
        best=.array~of(x,y)
        bestWeight=scored[2]
        bestCount=scored[1]
      end
      else if scored[2]=bestWeight then do
        if scored[1]>bestCount then do
          best=.array~of(x,y)
          bestCount=scored[1]
        end
      end
    end
  end
  return best

::method scoreCandidate class
  use strict arg x,y,segments,tanTolerance
  count=0; weight=0
  do segment over segments
    if self~withinAngle(segment,x,y,tanTolerance) then do
      count=count+1
      weight=weight+segment~length
    end
  end
  return .array~of(count,weight)

::method withinAngle class
  use strict arg segment,x,y,tanTolerance
  dx=segment~dx; dy=segment~dy
  rx=x-segment~midX; ry=y-segment~midY
  cross=(dx*ry-dy*rx)~abs
  dot=(dx*rx+dy*ry)~abs
  if dot=0 then return cross=0
  return cross<=tanTolerance*dot

::method angularErrorDegrees class
  use strict arg segment,x,y,ctx
  dx=segment~dx; dy=segment~dy
  rx=x-segment~midX; ry=y-segment~midY
  rayLength=.Maths~sqrt(rx*rx+ry*ry,ctx)
  if rayLength<'0.000000001' then return 90
  cross=(dx*ry-dy*rx)~abs
  dot=(dx*rx+dy*ry)~abs
  return .Maths~atan2(cross,dot,ctx)~degreesValue

::method refine class
  use strict arg seedX,seedY,segments,tanTolerance,ctx
  inliers=.array~new
  do segment over segments
    if self~withinAngle(segment,seedX,seedY,tanTolerance) then inliers~append(segment)
  end
  if inliers~items<2 then return .nil
  /* Weighted orthogonal line-distance least squares.  The 2x2 solve is owned
   * by Maths; Photo World owns only the image-line semantics. */
  saa=0; sab=0; sbb=0; rhsA=0; rhsB=0; totalWeight=0
  do segment over inliers
    w=segment~length
    a=segment~lineA; b=segment~lineB; c=segment~lineC
    saa=saa+w*a*a; sab=sab+w*a*b; sbb=sbb+w*b*b
    rhsA=rhsA-w*a*c; rhsB=rhsB-w*b*c
    totalWeight=totalWeight+w
  end
  determinant=saa*sbb-sab*sab
  if determinant~abs<'0.000000000001' then return .nil
  matrix=.Maths~matrix(.array~of(.array~of(saa,sab),.array~of(sab,sbb)),ctx)
  rhs=.Maths~vector(.array~of(rhsA,rhsB),ctx)
  solved=matrix~solve(rhs)
  x=solved[1]; y=solved[2]
  /* Re-evaluate membership against the refined point. */
  finalInliers=.array~new; squared=0; finalWeight=0
  do segment over segments
    if self~withinAngle(segment,x,y,tanTolerance) then do
      finalInliers~append(segment)
      d=segment~perpendicularDistance(x,y)
      w=segment~length
      squared=squared+w*d*d
      finalWeight=finalWeight+w
    end
  end
  if finalInliers~items<2 then return .nil
  rms=.Maths~sqrt(squared/finalWeight,ctx)
  return .SurveyVanishingPoint~new(x,y,finalInliers,rms,finalWeight,ctx)

::class SurveyManhattanLensCheck public
::attribute diagonalFovDegrees get
::attribute focalPixels get
::attribute orthogonalityRms get
::attribute pairDots get
::attribute valid get
::attribute context get
::method init
  expose diagonalFovDegrees focalPixels orthogonalityRms pairDots valid context
  use strict arg imageWidth,imageHeight,diagonalFovDegrees,solution,context=.nil
  if context==.nil then context=.MathContext~decimal(30)
  valid=.false; focalPixels=.nil; orthogonalityRms=.nil; pairDots=.array~new
  if solution~pointCount<3 then return
  diagonalPixels=.Maths~sqrt(imageWidth*imageWidth+imageHeight*imageHeight,context)
  halfAngle=.MathAngle~degrees(diagonalFovDegrees,context)~radiansValue/2
  focalPixels=(diagonalPixels/2)/.Maths~tan(halfAngle,context)
  directions=.array~new
  cx=imageWidth/2; cy=imageHeight/2
  pointCount=0
  do point over solution~points
    pointCount=pointCount+1
    if pointCount>3 then leave
    vector=.MathVector3~new(point~x-cx,cy-point~y,focalPixels,context)~normalized
    directions~append(vector)
  end
  d12=(directions[1]*directions[2])~abs
  d13=(directions[1]*directions[3])~abs
  d23=(directions[2]*directions[3])~abs
  pairDots=.array~of(d12,d13,d23)
  orthogonalityRms=.Maths~sqrt((d12*d12+d13*d13+d23*d23)/3,context)
  valid=.true

::class SurveyManhattanLensSelector public
::method choose class
  use strict arg imageWidth,imageHeight,solution,candidateDiagonalFovs,maxOrthogonalityRms='0.20'
  checks=.array~new; best=.nil
  do fov over candidateDiagonalFovs
    check=.SurveyManhattanLensCheck~new(imageWidth,imageHeight,fov,solution,solution~context)
    checks~append(check)
    if check~valid then do
      if best==.nil then best=check
      else if check~orthogonalityRms<best~orthogonalityRms then best=check
    end
  end
  if best<>.nil then do
    if best~orthogonalityRms>maxOrthogonalityRms then best=.nil
  end
  return .array~of(best,checks)

::class SurveySegmentSvg public
::method render class
  use strict arg collection,solution,path,title='Photo Survey World - image structure / vanishing families'
  width=collection~imageWidth; height=collection~imageHeight
  if width<=0 then raise syntax 88.900 array('known image width',width)
  if height<=0 then raise syntax 88.900 array('known image height',height)
  colors=.array~of('#c62828','#1565c0','#2e7d32','#777777')
  lines=.array~new
  lines~append('<svg xmlns="http://www.w3.org/2000/svg" width="'width'" height="'height+95'" viewBox="0 0 'width' 'height+95'">')
  lines~append('<rect width="100%" height="100%" fill="white"/>')
  lines~append('<rect x="0" y="0" width="'width'" height="'height'" fill="#f7f7f7" stroke="#222"/>')
  do segment over collection~segments
    family=solution~familyIndexFor(segment)
    color='#9e9e9e'
    if family>0 then if family<=3 then color=colors[family]
    lines~append('<line x1="'segment~x1'" y1="'segment~y1'" x2="'segment~x2'" y2="'segment~y2'" stroke="'color'" stroke-width="2"/>')
  end
  lines~append('<text x="12" y="'height+24'" font-family="sans-serif" font-size="16">'title'</text>')
  status='segments='collection~count' vanishing-families='solution~pointCount' unresolved='solution~unresolvedSegmentCount
  lines~append('<text x="12" y="'height+48'" font-family="sans-serif" font-size="13">'status'</text>')
  xText=12; familyNumber=0
  do point over solution~points
    familyNumber=familyNumber+1
    label='F'familyNumber': inliers='point~inlierCount' VP=('point~x~format(,1)','point~y~format(,1)') rms='point~rmsPixels~format(,2)'px'
    lines~append('<text x="'xText'" y="'height+72'" font-family="sans-serif" font-size="12" fill="'colors[familyNumber]'">'label'</text>')
    xText=xText+width/3
  end
  lines~append('</svg>')
  call lineout path
  do line over lines; call lineout path,line; end
  call lineout path
  return path

::requires 'MathsBootstrap.cls'
