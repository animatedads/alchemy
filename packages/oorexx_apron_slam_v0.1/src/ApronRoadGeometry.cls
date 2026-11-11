/* Apron SLAM — physical road/camera/vehicle-box hypothesis v0.1-dev3.
 * All coordinates in metres. Camera origin world (0,0,H), world X along road,
 * Y across road, Z upwards. Vehicle moves in the -X direction.
 * This class NEVER reads, stores or serialises real plates, video or identifiers.
 * Maths is the sole trig/sqrt authority for angle factories and magnitudes.
 */
::options digits 30

::class ApronRoadBasis public
::attribute yawSin get
::attribute yawCos get
::attribute pitchSin get
::attribute pitchCos get
::attribute rollSin get
::attribute rollCos get
::method init
  expose yawSin yawCos pitchSin pitchCos rollSin rollCos
  use strict arg ys,yc,ps,pc,rs,rc
  if abs(ys*ys+yc*yc-1)>'0.00001' | -
     abs(ps*ps+pc*pc-1)>'0.00001' | -
     abs(rs*rs+rc*rc-1)>'0.00001' then -
    raise syntax 88.900 array('non-unit road camera orientation basis')
  yawSin=ys+0; yawCos=yc+0
  pitchSin=ps+0; pitchCos=pc+0
  rollSin=rs+0; rollCos=rc+0
::method fromDegrees class
  use strict arg yawDegrees,pitchDegrees,rollDegrees,context=.nil
  if context==.nil then context=.MathContext~decimal(30)
  ya=.Maths~angleDegrees(yawDegrees,context)
  pa=.Maths~angleDegrees(pitchDegrees,context)
  ra=.Maths~angleDegrees(rollDegrees,context)
  return self~new(.Maths~sin(ya),.Maths~cos(ya), -
                  .Maths~sin(pa),.Maths~cos(pa), -
                  .Maths~sin(ra),.Maths~cos(ra))

::class ApronRoadCamera public
::attribute width get
::attribute height get
::attribute focalX get
::attribute focalY get
::attribute elevationMetres get
::attribute radialK1 get
::method init
  expose width height focalX focalY elevationMetres radialK1 basis
  use strict arg w,h,fx,fy,cameraHeight,orientation,k1=0
  if \datatype(w,'W') | \datatype(h,'W') | w<1 | h<1 | -
     \datatype(fx,'N') | \datatype(fy,'N') | fx<=0 | fy<=0 | -
     \datatype(cameraHeight,'N') | cameraHeight<=0 | -
     \orientation~isA(.ApronRoadBasis) | -
     \datatype(k1,'N') | k1<-.8 | k1>.8 then -
     raise syntax 88.900 array('invalid road camera calibration hypothesis')
  width=w; height=h; focalX=fx; focalY=fy
  elevationMetres=cameraHeight; radialK1=k1; basis=orientation
::method basis
  expose basis
  return basis
::method project
  expose width height focalX focalY elevationMetres radialK1 basis
  use strict arg worldPoint
  if \worldPoint~isA(.Array) | worldPoint~items<>3 then -
    raise syntax 88.900 array('3D point Array required')
  x=worldPoint[1];y=worldPoint[2];z=worldPoint[3]-elevationMetres
  along=basis~yawCos*x+basis~yawSin*y
  depth=basis~pitchCos*along-basis~pitchSin*z
  if depth<=0 then raise syntax 88.900 array('point behind road camera')
  nx=(basis~yawSin*x-basis~yawCos*y)/depth
  ny=-(basis~pitchSin*along+basis~pitchCos*z)/depth
  factor=1+radialK1*(nx*nx+ny*ny)
  if factor<=0 then raise syntax 88.900 array('radial projection has folded')
  nx=nx*factor;ny=ny*factor
  u=width/2+focalX*(basis~rollCos*nx-basis~rollSin*ny)
  v=height/2+focalY*(basis~rollSin*nx+basis~rollCos*ny)
  return .array~of(u,v)

::class ApronRoadSection public
::attribute widthMetres get
::attribute lateralCentre get
::method init
  expose widthMetres lateralCentre
  use strict arg carriagewayWidth,lateralY
  if \datatype(carriagewayWidth,'N') | carriagewayWidth<2.75 | carriagewayWidth>30 | -
     \datatype(lateralY,'N') then -
    raise syntax 88.900 array('invalid road section')
  widthMetres=carriagewayWidth; lateralCentre=lateralY
::method edgeY
  expose widthMetres lateralCentre
  use strict arg side
  if side<>-1 & side<>1 then raise syntax 88.900 array('road side must be -1 or +1')
  return lateralCentre+side*widthMetres/2
::method edgesAt
  use strict arg worldX
  return .array~of(.array~of(worldX,self~edgeY(-1),0), -
                   .array~of(worldX,self~edgeY(1),0))

::class ApronRoadCarBox public
::attribute lengthMetres get
::attribute widthMetres get
::attribute heightMetres get
::attribute plateWidth get
::attribute plateHeight get
::attribute plateZ get
::method init
  expose lengthMetres widthMetres heightMetres plateWidth plateHeight plateZ
  use strict arg L=4.4,W=1.82,H=1.53,PW=.520,PH=.111,PZ=.55
  if L<2.0 | W<1.1 | H<1.0 | PW<=0 | PH<=0 | -
     PW>W | PH>H | PZ-PH/2<0 | PZ+PH/2>H then -
    raise syntax 88.900 array('invalid vehicle or plate physical dimensions')
  lengthMetres=L; widthMetres=W; heightMetres=H
  plateWidth=PW;plateHeight=PH;plateZ=PZ
::method cornersAt
  expose lengthMetres widthMetres heightMetres
  use strict arg xCentre,yCentre
  points=.array~new
  do frontBack over .array~of(-1,1)
    do leftRight over .array~of(-1,1)
      do z over .array~of(0,heightMetres)
        points~append(.array~of(xCentre+frontBack*lengthMetres/2, -
                      yCentre+leftRight*widthMetres/2,z))
      end
    end
  end
  return points
::method plateQuadAt
  expose lengthMetres plateWidth plateHeight plateZ
  use strict arg xCentre,yCentre
  xFront=xCentre-lengthMetres/2
  halfW=plateWidth/2;halfH=plateHeight/2
  return .array~of(.array~of(xFront,yCentre-halfW,plateZ-halfH), -
                   .array~of(xFront,yCentre+halfW,plateZ-halfH), -
                   .array~of(xFront,yCentre+halfW,plateZ+halfH), -
                   .array~of(xFront,yCentre-halfW,plateZ+halfH))

::class ApronRoadScene public
::attribute camera get
::attribute road get
::attribute vehicle get
::attribute speedMetresSecond get
::attribute frameRate get
::method init
  expose camera road vehicle xInitial yCar speedMetresSecond frameRate
  use strict arg cam,section,box,startX,carY,speedMs,fps=25
  if \cam~isA(.ApronRoadCamera) | \section~isA(.ApronRoadSection) | -
     \box~isA(.ApronRoadCarBox) | \datatype(speedMs,'N') | speedMs<0 | -
     \datatype(fps,'N') | fps<1 | fps>240 then -
    raise syntax 88.900 array('invalid road-scene components')
  if carY-box~widthMetres/2<section~edgeY(-1) | -
     carY+box~widthMetres/2>section~edgeY(1) then -
    raise syntax 88.900 array('vehicle outside road boundaries')
  camera=cam;road=section;vehicle=box
  xInitial=startX;yCar=carY;speedMetresSecond=speedMs;frameRate=fps
::method positionAt
  expose xInitial yCar speedMetresSecond
  use strict arg seconds
  if \datatype(seconds,'N') | seconds<0 then -
    raise syntax 88.900 array('nonnegative source-relative time required')
  return .array~of(xInitial-speedMetresSecond*seconds,yCar)
::method projectedBoxAt
  expose camera vehicle
  use strict arg seconds
  p=self~positionAt(seconds)
  minU=1e99;minV=1e99;maxU=-1e99;maxV=-1e99
  do pt over vehicle~cornersAt(p[1],p[2])
    v=camera~project(pt)
    minU=min(minU,v[1]);minV=min(minV,v[2]);maxU=max(maxU,v[1]);maxV=max(maxV,v[2])
  end
  return .array~of(minU,minV,maxU-minU,maxV-minV)
::method projectedPlateAt
  expose camera vehicle
  use strict arg seconds
  p=self~positionAt(seconds)
  q=.array~new
  do pt over vehicle~plateQuadAt(p[1],p[2])
    q~append(camera~project(pt))
  end
  return q
::method platePixelDimensionsSquared
  use strict arg seconds
  pts=self~projectedPlateAt(seconds)
  width2=(pts[2][1]-pts[1][1])**2+(pts[2][2]-pts[1][2])**2
  height2=(pts[4][1]-pts[1][1])**2+(pts[4][2]-pts[1][2])**2
  return .array~of(width2,height2)
::method platePixelDimensions
  use strict arg seconds,context=.nil
  p=self~platePixelDimensionsSquared(seconds)
  return .array~of(.Maths~sqrt(p[1],context),.Maths~sqrt(p[2],context))
::method plateCentroidAt
  use strict arg seconds
  pts=self~projectedPlateAt(seconds)
  u=0;v=0
  do point over pts
    u=u+point[1]/4;v=v+point[2]/4
  end
  return .array~of(u,v)
::method plateExposureDisplacement
  expose frameRate
  use strict arg seconds,exposureUs
  if \datatype(exposureUs,'W') | exposureUs<1 | exposureUs>1000000/frameRate | -
     \datatype(seconds,'N') | seconds<exposureUs/2000000 then -
    raise syntax 88.900 array('invalid source-relative shutter interval')
  first=self~plateCentroidAt(seconds-exposureUs/2000000)
  last=self~plateCentroidAt(seconds+exposureUs/2000000)
  return .array~of(last[1]-first[1],last[2]-first[2])
::method roadEdgesAt
  expose road camera
  use strict arg worldX
  out=.array~new
  do point over road~edgesAt(worldX)
    out~append(camera~project(point))
  end
  return out
::method boxResidualSquared
  use strict arg seconds,observedBox
  if \observedBox~isA(.Array) | observedBox~items<>4 then -
    raise syntax 88.900 array('observed XYWH rectangle Array required')
  pred=self~projectedBoxAt(seconds)
  cost=0
  do i=1 to 4
    diff=pred[i]-observedBox[i]
    cost=cost+diff*diff
  end
  return cost
