/* Photo Survey World: explicit 2-D control observations and weighted similarity registration.
   This class NEVER discovers image features.  A caller supplies correspondences explicitly.
   The solved transform maps image/evidence coordinates into the local survey XY frame. */

::class SurveyControlPoint public
::method init
  expose _id _ix _iy _wx _wy _weight _source _uncertainty
  use strict arg id,ix,iy,wx,wy,weight=1.0,source='MANUAL',uncertainty=1.0
  if weight<=0 then raise syntax 88.900 array('weight must be > 0')
  _id=id; _ix=ix; _iy=iy; _wx=wx; _wy=wy; _weight=weight
  _source=source~upper; _uncertainty=uncertainty
::method id
  expose _id
  return _id
::method ix
  expose _ix
  return _ix
::method iy
  expose _iy
  return _iy
::method wx
  expose _wx
  return _wx
::method wy
  expose _wy
  return _wy
::method weight
  expose _weight
  return _weight
::method source
  expose _source
  return _source
::method uncertainty
  expose _uncertainty
  return _uncertainty

::class SurveySimilarity2D public
::method init
  expose _scale _cos _sin _tx _ty _rms _count
  use strict arg scale,cosv,sinv,tx,ty,rms,count
  _scale=scale; _cos=cosv; _sin=sinv; _tx=tx; _ty=ty; _rms=rms; _count=count
::method scale
  expose _scale
  return _scale
::method cos
  expose _cos
  return _cos
::method sin
  expose _sin
  return _sin
::method tx
  expose _tx
  return _tx
::method ty
  expose _ty
  return _ty
::method rms
  expose _rms
  return _rms
::method count
  expose _count
  return _count
::method map
  expose _scale _cos _sin _tx _ty
  use strict arg x,y
  ox=_tx+_scale*(_cos*x-_sin*y)
  oy=_ty+_scale*(_sin*x+_cos*y)
  return ox','oy
::method residual
  use strict arg cp
  parse value self~map(cp~ix,cp~iy) with x ',' y
  dx=x-cp~wx; dy=y-cp~wy
  return .Maths~sqrt(dx*dx+dy*dy,.Maths~defaultContext)

::class SurveyRegistration2D public
::method solveSimilarity class
  use strict arg controls
  if controls~items<2 then raise syntax 88.900 array('at least two controls required')
  sw=0; ixm=0; iym=0; wxm=0; wym=0
  do c over controls
    w=c~weight; sw=sw+w
    ixm=ixm+w*c~ix; iym=iym+w*c~iy
    wxm=wxm+w*c~wx; wym=wym+w*c~wy
  end
  ixm=ixm/sw; iym=iym/sw; wxm=wxm/sw; wym=wym/sw
  a=0; b=0; den=0
  do c over controls
    w=c~weight; ixd=c~ix-ixm; iyd=c~iy-iym; wxd=c~wx-wxm; wyd=c~wy-wym
    a=a+w*(ixd*wxd+iyd*wyd)
    b=b+w*(ixd*wyd-iyd*wxd)
    den=den+w*(ixd*ixd+iyd*iyd)
  end
  if den=0 then raise syntax 88.900 array('degenerate controls')
  mag=.Maths~sqrt(a*a+b*b,.Maths~defaultContext)
  if mag=0 then raise syntax 88.900 array('degenerate registration')
  cosv=a/mag; sinv=b/mag; scale=mag/den
  tx=wxm-scale*(cosv*ixm-sinv*iym)
  ty=wym-scale*(sinv*ixm+cosv*iym)
  sum=0
  t=.SurveySimilarity2D~new(scale,cosv,sinv,tx,ty,0,controls~items)
  do c over controls
    r=t~residual(c); sum=sum+c~weight*r*r
  end
  rms=.Maths~sqrt(sum/sw,.Maths~defaultContext)
  return .SurveySimilarity2D~new(scale,cosv,sinv,tx,ty,rms,controls~items)

::class SurveyEvidenceFrame public
::method init
  expose _id _width _height _kind _controls _transform
  use strict arg id,width,height,kind='AERIAL_SCREENSHOT'
  _id=id; _width=width; _height=height; _kind=kind~upper
  _controls=.array~new; _transform=.nil
::method id
  expose _id
  return _id
::method width
  expose _width
  return _width
::method height
  expose _height
  return _height
::method kind
  expose _kind
  return _kind
::method addControl
  expose _controls
  use strict arg c
  _controls~append(c); return c
::method controls
  expose _controls
  return _controls~copy
::method solve
  expose _controls _transform
  _transform=.SurveyRegistration2D~solveSimilarity(_controls)
  return _transform
::method transform
  expose _transform
  return _transform
::method mapPoint
  expose _transform
  use strict arg x,y
  if _transform==.nil then raise syntax 88.900 array('frame has not been solved')
  return _transform~map(x,y)

::requires 'MathsBootstrap.cls'
