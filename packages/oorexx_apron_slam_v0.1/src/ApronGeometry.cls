/* Apron SLAM v0.1 — source-time-based 3D camera/vehicle/plate projection.
 * Physical distances are metres, times are seconds unless suffixed Us.
 * World camera convention: X right, Y away from camera, Z up.
 * Camera optical axis +Y, level, principal point (cx,cy).
 * Geometry is deliberately independent of codec or font provider.
 * Maths owns orientation trigonometry through the fromYawDegrees factory;
 * tests may inject independently measured orientation components.
 */
::options digits 30

::class ApronOrientation public
::attribute sine get
::attribute cosine get
::attribute yawDegrees get
::method init
  expose sine cosine yawDegrees
  use strict arg yaw, sinValue, cosValue
  numeric digits 30
  residual = abs(sinValue*sinValue+cosValue*cosValue-1)
  if residual > '0.0000001' then raise syntax 88.900 array('orientation basis not unit length',residual)
  sine=sinValue+0; cosine=cosValue+0; yawDegrees=yaw
::method fromYawDegrees class
  use strict arg yaw, ctx=.nil
  if ctx == .nil then ctx=.MathContext~decimal(30)
  angle=.Maths~angleDegrees(yaw,ctx)
  return self~new(yaw,.Maths~sin(angle),.Maths~cos(angle))

::class ApronCamera public
::attribute width get
::attribute height get
::attribute fx get
::attribute fy get
::attribute cx get
::attribute cy get
::attribute cameraHeight get
::method init
  expose width height fx fy cx cy cameraHeight
  use strict arg imageWidth,imageHeight,focalX,focalY,heightMetres
  if imageWidth<1 | imageHeight<1 | focalX<=0 | focalY<=0 | heightMetres<0 then -
    raise syntax 88.900 array('invalid pinhole camera')
  width=imageWidth; height=imageHeight; fx=focalX; fy=focalY
  cx=imageWidth/2; cy=imageHeight/2; cameraHeight=heightMetres
::method project
  expose fx fy cx cy cameraHeight
  use strict arg x,y,z
  if y<=0 then raise syntax 88.900 array('point behind camera or on near plane')
  return .array~of(cx+fx*x/y,cy-fy*(z-cameraHeight)/y)

::class ApronCarBox public
::attribute lengthMetres get
::attribute widthMetres get
::attribute heightMetres get
::attribute plateWidth get
::attribute plateHeight get
::attribute plateCentreHeight get
::attribute orientation get
::method init
  expose lengthMetres widthMetres heightMetres plateWidth plateHeight plateCentreHeight orientation
  use strict arg basis,vehicleLength=4.3,vehicleWidth=1.8,vehicleHeight=1.5, -
    plateW=.520,plateH=.111,plateZ=.55
  if \basis~isA(.ApronOrientation) then raise syntax 88.900 array('ApronOrientation required')
  if vehicleLength<=0 | vehicleWidth<=0 | vehicleHeight<=0 | plateW<=0 | plateH<=0 | -
    plateW>vehicleWidth | plateH>vehicleHeight | plateZ<plateH/2 | -
    plateZ+plateH/2>vehicleHeight then raise syntax 88.900 array('invalid car or plate dimensions')
  orientation=basis; lengthMetres=vehicleLength; widthMetres=vehicleWidth
  heightMetres=vehicleHeight; plateWidth=plateW; plateHeight=plateH; plateCentreHeight=plateZ
::method plateCentreAt
  expose orientation plateCentreHeight
  use strict arg x0,y0,speedMetresSecond,timeSeconds
  if speedMetresSecond<0 then raise syntax 88.900 array('negative speed')
  if timeSeconds<0 then raise syntax 88.900 array('negative source time')
  return .array~of(x0+speedMetresSecond*timeSeconds*orientation~sine, -
                   y0-speedMetresSecond*timeSeconds*orientation~cosine,plateCentreHeight)
::method platePointAt
  expose orientation
  use strict arg centre,plateHorizontal,plateVertical
  /* Horizontal plate right vector (cos yaw,sin yaw,0), upward (0,0,1). */
  return .array~of(centre[1]+plateHorizontal*orientation~cosine, -
                   centre[2]+plateHorizontal*orientation~sine,centre[3]+plateVertical)
::method plateCornersAt
  expose plateWidth plateHeight
  use strict arg centre
  h=plateWidth/2; v=plateHeight/2
  return .array~of(self~platePointAt(centre,-h,-v),self~platePointAt(centre,h,-v), -
                   self~platePointAt(centre,h,v),self~platePointAt(centre,-h,v))
::method glyphCornersAt
  use strict arg centre,charWidthMetres=.050,charHeightMetres=.079,charOffsetMetres=0
  h=charWidthMetres/2; v=charHeightMetres/2
  return .array~of(self~platePointAt(centre,charOffsetMetres-h,-v), -
                   self~platePointAt(centre,charOffsetMetres+h,-v), -
                   self~platePointAt(centre,charOffsetMetres+h,v), -
                   self~platePointAt(centre,charOffsetMetres-h,v))
::method bodyCornersAt
  expose orientation widthMetres heightMetres lengthMetres
  use strict arg plateCentre
  /* Plate at front; body extends backwards along opposite of outward normal. */
  out=.array~new
  do forwardIndex=0 to 1
    d=forwardIndex*lengthMetres
    do side over .array~of(-1,1)
      do z over .array~of(0,heightMetres)
        x=plateCentre[1]-d*orientation~sine+side*widthMetres/2*orientation~cosine
        y=plateCentre[2]+d*orientation~cosine+side*widthMetres/2*orientation~sine
        out~append(.array~of(x,y,z))
      end
    end
  end
  return out

::class ApronDriveBy public
::attribute camera get
::attribute vehicle get
::attribute speed get
::attribute frameRate get
::attribute exposureUs get
::attribute x0 get
::attribute y0 get
::method init
  expose camera vehicle speed frameRate exposureUs x0 y0
  use strict arg cam,car,startX,startY,speedKmH,fps,shutterMicroseconds
  if \cam~isA(.ApronCamera) | \car~isA(.ApronCarBox) then -
    raise syntax 88.900 array('camera and vehicle required')
  if startY<=0 | speedKmH<0 | fps<=0 | shutterMicroseconds<=0 | -
    shutterMicroseconds>1000000/fps then raise syntax 88.900 array('invalid physical drive-by schedule')
  camera=cam; vehicle=car; x0=startX; y0=startY
  speed=speedKmH/3.6; frameRate=fps; exposureUs=shutterMicroseconds
::method exposureSample
  expose camera vehicle speed x0 y0 exposureUs frameRate
  use strict arg frameIndex, sampleIndex, samples=9,charWidthMetres=.050
  if frameIndex<0 | sampleIndex<0 | samples<2 | sampleIndex>=samples then -
    raise syntax 88.900 array('invalid exposure sample')
  frameTime=frameIndex/frameRate
  time=frameTime+((sampleIndex/(samples-1))-.5)*exposureUs/1000000
  if time<0 then raise syntax 88.900 array('negative exposure time')
  c=vehicle~plateCentreAt(x0,y0,speed,time)
  quad=vehicle~glyphCornersAt(c,charWidthMetres)
  outQuad=.array~new
  do vertex over quad
    projected=camera~project(vertex[1],vertex[2],vertex[3])
    outQuad~append(projected)
  end
  return outQuad
::method projectedPlateCentre
  expose camera vehicle speed x0 y0
  use strict arg timeSeconds
  c=vehicle~plateCentreAt(x0,y0,speed,timeSeconds)
  return camera~project(c[1],c[2],c[3])
::method blurVector
  use strict arg frameIndex,samples=9
  first=self~exposureSample(frameIndex,0,samples)
  last=self~exposureSample(frameIndex,samples-1,samples)
  sumU=0;sumV=0
  do i=1 to 4
    sumU=sumU+(last[i][1]-first[i][1]);sumV=sumV+(last[i][2]-first[i][2])
  end
  return .array~of(sumU/4,sumV/4)