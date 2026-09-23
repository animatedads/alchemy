/* ooRexx ML Graph v0.1-dev6
 * Raster/image technical-visualisation primitives.
 *
 * The source image remains immutable evidence.  Vector overlays are semantic
 * presentation objects layered above it.  Renderers own compositing/pixels.
 */

::class MLImageColour public
::method init
  expose _r _g _b _a
  use strict arg r,g,b,a=1
  self~validateChannel(r,'red'); self~validateChannel(g,'green'); self~validateChannel(b,'blue')
  if \datatype(a,'N') | a<0 | a>1 then raise syntax 88.900 array('image alpha must be between 0 and 1',a)
  _r=r+0; _g=g+0; _b=b+0; _a=a+0
::method rgb class; use strict arg r,g,b; return .MLImageColour~new(r,g,b,1)
::method rgba class; use strict arg r,g,b,a; return .MLImageColour~new(r,g,b,a)
::method black class; return .MLImageColour~new(0,0,0,1)
::method white class; return .MLImageColour~new(255,255,255,1)
::method red class; return .MLImageColour~new(255,0,0,1)
::method green class; return .MLImageColour~new(0,255,0,1)
::method blue class; return .MLImageColour~new(0,0,255,1)
::method yellow class; return .MLImageColour~new(255,255,0,1)
::method cyan class; return .MLImageColour~new(0,255,255,1)
::method magenta class; return .MLImageColour~new(255,0,255,1)
::method r; expose _r; return _r
::method g; expose _g; return _g
::method b; expose _b; return _b
::method a; expose _a; return _a
::method withAlpha
  expose _r _g _b
  use strict arg alpha
  return .MLImageColour~new(_r,_g,_b,alpha)
::method hex
  expose _r _g _b
  return '#'||self~hexByte(_r)||self~hexByte(_g)||self~hexByte(_b)
::method rgba255
  expose _r _g _b _a
  return .array~of(_r,_g,_b,format(_a*255,,0))
::method canonicalText
  expose _r _g _b _a
  return 'RGBA='||_r||','||_g||','||_b||','||_a
::method validateChannel private
  use strict arg value,name
  if \datatype(value,'W') | value<0 | value>255 then raise syntax 88.900 array('image colour channel must be integer 0..255',name,value)
::method hexByte private
  use strict arg value
  h=d2x(value,2)
  return h~upper

::class MLImageStyle public
::method init
  expose _stroke _fill _strokeWidth _opacity _dash _lineCap _lineJoin _fillRule
  use strict arg stroke=.nil,fill=.nil,strokeWidth=1,opacity=1,dash='',lineCap='ROUND',lineJoin='ROUND',fillRule='NONZERO'
  if stroke \== .nil then if \stroke~isA(.MLImageColour) then raise syntax 88.900 array('image stroke must be MLImageColour or nil')
  if fill \== .nil then if \fill~isA(.MLImageColour) then raise syntax 88.900 array('image fill must be MLImageColour or nil')
  if \datatype(strokeWidth,'N') | strokeWidth<0 then raise syntax 88.900 array('image stroke width must be >= 0',strokeWidth)
  if \datatype(opacity,'N') | opacity<0 | opacity>1 then raise syntax 88.900 array('image style opacity must be between 0 and 1',opacity)
  _stroke=stroke; _fill=fill; _strokeWidth=strokeWidth+0; _opacity=opacity+0; _dash=dash~string
  _lineCap=lineCap~string~upper; _lineJoin=lineJoin~string~upper; _fillRule=fillRule~string~upper
  if _lineCap<>'BUTT' & _lineCap<>'ROUND' & _lineCap<>'SQUARE' then raise syntax 88.900 array('unsupported image line cap',_lineCap)
  if _lineJoin<>'MITER' & _lineJoin<>'ROUND' & _lineJoin<>'BEVEL' then raise syntax 88.900 array('unsupported image line join',_lineJoin)
  if _fillRule<>'NONZERO' & _fillRule<>'EVENODD' then raise syntax 88.900 array('unsupported image fill rule',_fillRule)
::method stroke class
  use strict arg colour,width=1,opacity=1
  return .MLImageStyle~new(colour,.nil,width,opacity)
::method fill class
  use strict arg colour,opacity=1
  return .MLImageStyle~new(.nil,colour,0,opacity)
::method strokeFill class
  use strict arg stroke,fill,width=1,opacity=1
  return .MLImageStyle~new(stroke,fill,width,opacity)
::method stroke; expose _stroke; return _stroke
::method fill; expose _fill; return _fill
::method strokeWidth; expose _strokeWidth; return _strokeWidth
::method opacity; expose _opacity; return _opacity
::method dash; expose _dash; return _dash
::method lineCap; expose _lineCap; return _lineCap
::method lineJoin; expose _lineJoin; return _lineJoin
::method fillRule; expose _fillRule; return _fillRule
::method canonicalText
  expose _stroke _fill _strokeWidth _opacity _dash _lineCap _lineJoin _fillRule
  s='nil'; if _stroke \== .nil then s=_stroke~canonicalText
  f='nil'; if _fill \== .nil then f=_fill~canonicalText
  return 'STYLE=stroke('||s||')|fill('||f||')|width='||_strokeWidth||'|opacity='||_opacity||'|dash='||_dash||'|cap='||_lineCap||'|join='||_lineJoin||'|fillRule='||_fillRule

::class MLImageVertex public
::method init
  expose _x _y _evidence
  use strict arg x,y,evidence=.nil
  if \datatype(x,'N') | \datatype(y,'N') then raise syntax 88.900 array('image vertex coordinates must be numeric',x,y)
  _x=x+0; _y=y+0; _evidence=evidence
::method x; expose _x; return _x
::method y; expose _y; return _y
::method evidence; expose _evidence; return _evidence
::method canonicalText; expose _x _y; return 'VERTEX='||_x||','||_y

::class MLImageGeometry public
::method vertex class
  use strict arg value
  if value~isA(.MLImageVertex) then return value
  if value~isA(.Array) then do
    if value~items<2 then raise syntax 88.900 array('image coordinate array requires x and y')
    return .MLImageVertex~new(value[1],value[2])
  end
  raise syntax 88.900 array('image coordinate must be MLImageVertex or [x,y] Array')
::method vertices class
  use strict arg values,minCount=1
  if \values~isA(.Array) then raise syntax 88.900 array('image points must be an Array')
  if values~items<minCount then raise syntax 88.900 array('image primitive has too few points',values~items,minCount)
  out=.array~new
  do v over values; out~append(self~vertex(v)); end
  return out

::class MLImagePrimitive public
::method init
  expose _kind _style _evidence _space _semanticKey _label
  use strict arg kind,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  if \style~isA(.MLImageStyle) then raise syntax 88.900 array('image primitive style must be MLImageStyle')
  _kind=kind~string~upper; _style=style; _evidence=evidence; _space=space~string~upper; _semanticKey=semanticKey~string; _label=label~string
  if _space<>'PIXEL' & _space<>'NORMALIZED' then raise syntax 88.900 array('image coordinate space must be PIXEL or NORMALIZED',_space)
::method kind; expose _kind; return _kind
::method style; expose _style; return _style
::method evidence; expose _evidence; return _evidence
::method coordinateSpace; expose _space; return _space
::method semanticKey; expose _semanticKey; return _semanticKey
::method label; expose _label; return _label

::class MLImageLine subclass MLImagePrimitive public
::method init
  expose _p1 _p2
  use strict arg p1,p2,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  self~init:super('LINE',style,evidence,space,semanticKey,label)
  _p1=.MLImageGeometry~vertex(p1); _p2=.MLImageGeometry~vertex(p2)
::method p1; expose _p1; return _p1
::method p2; expose _p2; return _p2

::class MLImagePolyline subclass MLImagePrimitive public
::method init
  expose _points
  use strict arg points,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  self~init:super('POLYLINE',style,evidence,space,semanticKey,label)
  _points=.MLImageGeometry~vertices(points,2)
::method points; expose _points; return _points

::class MLImagePolygon subclass MLImagePrimitive public
::method init
  expose _points
  use strict arg points,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  self~init:super('POLYGON',style,evidence,space,semanticKey,label)
  _points=.MLImageGeometry~vertices(points,3)
::method points; expose _points; return _points

::class MLImageRectangle subclass MLImagePrimitive public
::method init
  expose _x _y _width _height _radius
  use strict arg x,y,width,height,style,evidence=.nil,space='PIXEL',radius=0,semanticKey='',label=''
  if width<0 | height<0 then raise syntax 88.900 array('image rectangle dimensions must be >= 0',width,height)
  if radius<0 then raise syntax 88.900 array('image rectangle radius must be >= 0',radius)
  self~init:super('RECTANGLE',style,evidence,space,semanticKey,label)
  _x=x+0; _y=y+0; _width=width+0; _height=height+0; _radius=radius+0
::method x; expose _x; return _x
::method y; expose _y; return _y
::method width; expose _width; return _width
::method height; expose _height; return _height
::method radius; expose _radius; return _radius

::class MLImageEllipse subclass MLImagePrimitive public
::method init
  expose _cx _cy _rx _ry
  use strict arg cx,cy,rx,ry,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  if rx<0 | ry<0 then raise syntax 88.900 array('image ellipse radii must be >= 0',rx,ry)
  self~init:super('ELLIPSE',style,evidence,space,semanticKey,label)
  _cx=cx+0; _cy=cy+0; _rx=rx+0; _ry=ry+0
::method cx; expose _cx; return _cx
::method cy; expose _cy; return _cy
::method rx; expose _rx; return _rx
::method ry; expose _ry; return _ry

::class MLImageCircle subclass MLImagePrimitive public
::method init
  expose _cx _cy _radius
  use strict arg cx,cy,radius,style,evidence=.nil,space='PIXEL',semanticKey='',label=''
  if radius<0 then raise syntax 88.900 array('image circle radius must be >= 0',radius)
  self~init:super('CIRCLE',style,evidence,space,semanticKey,label)
  _cx=cx+0; _cy=cy+0; _radius=radius+0
::method cx; expose _cx; return _cx
::method cy; expose _cy; return _cy
::method radius; expose _radius; return _radius

::class MLImageMarker subclass MLImagePrimitive public
::method init
  expose _x _y _radius _shape
  use strict arg x,y,radius,style,evidence=.nil,space='PIXEL',shape='CIRCLE',semanticKey='',label=''
  if radius<0 then raise syntax 88.900 array('image marker radius must be >= 0',radius)
  _shape=shape~string~upper
  if _shape<>'CIRCLE' & _shape<>'SQUARE' & _shape<>'CROSS' then raise syntax 88.900 array('unsupported image marker shape',_shape)
  self~init:super('MARKER',style,evidence,space,semanticKey,label)
  _x=x+0; _y=y+0; _radius=radius+0
::method x; expose _x; return _x
::method y; expose _y; return _y
::method radius; expose _radius; return _radius
::method shape; expose _shape; return _shape

::class MLImageText subclass MLImagePrimitive public
::method init
  expose _x _y _text _fontSize _anchor
  use strict arg x,y,text,style,evidence=.nil,space='PIXEL',fontSize=12,anchor='START',semanticKey='',label=''
  if fontSize<=0 then raise syntax 88.900 array('image text font size must be > 0',fontSize)
  _anchor=anchor~string~upper
  if _anchor<>'START' & _anchor<>'MIDDLE' & _anchor<>'END' then raise syntax 88.900 array('unsupported image text anchor',_anchor)
  self~init:super('TEXT',style,evidence,space,semanticKey,label)
  _x=x+0; _y=y+0; _text=text~string; _fontSize=fontSize+0
::method x; expose _x; return _x
::method y; expose _y; return _y
::method text; expose _text; return _text
::method fontSize; expose _fontSize; return _fontSize
::method anchor; expose _anchor; return _anchor

::class MLImageLayer public
::method init
  expose _name _opacity _visible _primitives _evidence _semanticKey
  use strict arg name,opacity=1,visible=.true,evidence=.nil,semanticKey=''
  if name='' then raise syntax 88.900 array('image layer name must not be empty')
  if \datatype(opacity,'N') | opacity<0 | opacity>1 then raise syntax 88.900 array('image layer opacity must be between 0 and 1',opacity)
  _name=name~string; _opacity=opacity+0; _visible=visible; _evidence=evidence; _semanticKey=semanticKey~string; _primitives=.array~new
::method name; expose _name; return _name
::method opacity; expose _opacity; return _opacity
::method visible; expose _visible; return _visible
::method evidence; expose _evidence; return _evidence
::method semanticKey; expose _semanticKey _name; if _semanticKey='' then return _name; return _semanticKey
::method add
  expose _primitives
  use strict arg primitive
  if \primitive~isA(.MLImagePrimitive) then raise syntax 88.900 array('image layer requires MLImagePrimitive')
  _primitives~append(primitive); return primitive
::method primitives
  expose _primitives
  out=.array~new; do p over _primitives; out~append(p); end; return out
::method primitiveCount; expose _primitives; return _primitives~items
::method primitiveAt; expose _primitives; use strict arg i; return _primitives[i]

::class MLImageSource public
::method width; raise syntax 88.900 array('abstract image source width')
::method height; raise syntax 88.900 array('abstract image source height')
::method colourAt; use strict arg x,y; raise syntax 88.900 array('abstract image source colourAt')
::method evidence; return .nil
::method sourceKind; return 'ABSTRACT'

::class MLImageArraySource subclass MLImageSource public
::method init
  expose _width _height _pixels _evidence
  use strict arg width,height,pixels,evidence=.nil
  if width<1 | height<1 then raise syntax 88.900 array('image source dimensions must be positive',width,height)
  if \pixels~isA(.Array) then raise syntax 88.900 array('image source pixels must be an Array')
  if pixels~items<>width*height then raise syntax 88.900 array('image source pixel count mismatch',pixels~items,width*height)
  _width=width; _height=height; _pixels=.array~new; _evidence=evidence
  do c over pixels
    if \c~isA(.MLImageColour) then raise syntax 88.900 array('image source pixel must be MLImageColour')
    _pixels~append(c)
  end
::method width; expose _width; return _width
::method height; expose _height; return _height
::method evidence; expose _evidence; return _evidence
::method sourceKind; return 'RGBA_ARRAY'
::method colourAt
  expose _width _height _pixels
  use strict arg x,y
  if x<0 | x>=_width | y<0 | y>=_height then raise syntax 88.900 array('image source coordinate out of range',x,y)
  return _pixels[y*_width+x+1]

::class MLVisionSurfaceImageSource subclass MLImageSource public
::method init
  expose _surface
  use strict arg surface
  /* Vision owns surface semantics; this adapter only reads its public contract. */
  if surface~width<1 | surface~height<1 then raise syntax 88.900 array('VisionSurface dimensions must be positive')
  _surface=surface
::method width; expose _surface; return _surface~width
::method height; expose _surface; return _surface~height
::method evidence; expose _surface; return _surface
::method sourceKind; return 'VISION_SURFACE'
::method surface; expose _surface; return _surface
::method colourAt
  expose _surface
  use strict arg x,y
  value=_surface~at(x,y); model=_surface~valueModel
  if model \== .nil then do
    if model~hasMethod('COLOUR') then do
      rgb=model~colour(value)
      return .MLImageColour~new(rgb[1],rgb[2],rgb[3],1)
    end
  end
  count=_surface~valueCount
  if count<=1 then level=0
  else level=format((value/(count-1))*255,,0)
  return .MLImageColour~new(level,level,level,1)

::class MLImageRenderOptions public
::method init
  expose _scale _includeBase _clipToImage
  use strict arg scale=1,includeBase=.true,clipToImage=.true
  if \datatype(scale,'N') | scale<=0 then raise syntax 88.900 array('image render scale must be > 0',scale)
  _scale=scale+0; _includeBase=includeBase; _clipToImage=clipToImage
::method scale; expose _scale; return _scale
::method includeBase; expose _includeBase; return _includeBase
::method clipToImage; expose _clipToImage; return _clipToImage

::class MLImageScene public
::method init
  expose _source _title _layers _metadata
  use strict arg source,title=''
  if \source~isA(.MLImageSource) then raise syntax 88.900 array('image scene source must be MLImageSource')
  _source=source; _title=title~string; _layers=.array~new; _metadata=.directory~new
::method forVisionSurface class
  use strict arg surface,title=''
  return .MLImageScene~new(.MLVisionSurfaceImageSource~new(surface),title)
::method source; expose _source; return _source
::method evidence; expose _source; return _source~evidence
::method width; expose _source; return _source~width
::method height; expose _source; return _source~height
::method title; expose _title; return _title
::method addLayer
  expose _layers
  use strict arg layer
  if \layer~isA(.MLImageLayer) then raise syntax 88.900 array('image scene requires MLImageLayer')
  _layers~append(layer); return layer
::method layer
  expose _layers
  use strict arg name
  do l over _layers; if l~name=name then return l; end
  return .nil
::method ensureLayer
  use strict arg name='overlay'
  l=self~layer(name); if l \== .nil then return l
  return self~addLayer(.MLImageLayer~new(name))
::method layers
  expose _layers
  out=.array~new; do l over _layers; out~append(l); end; return out
::method layerCount; expose _layers; return _layers~items
::method add
  use strict arg primitive,layerName='overlay'
  return self~ensureLayer(layerName)~add(primitive)
::method line
  use strict arg p1,p2,style,evidence=.nil,space='PIXEL',layerName='overlay',semanticKey='',label=''
  return self~add(.MLImageLine~new(p1,p2,style,evidence,space,semanticKey,label),layerName)
::method polyline
  use strict arg points,style,evidence=.nil,space='PIXEL',layerName='overlay',semanticKey='',label=''
  return self~add(.MLImagePolyline~new(points,style,evidence,space,semanticKey,label),layerName)
::method polygon
  use strict arg points,style,evidence=.nil,space='PIXEL',layerName='overlay',semanticKey='',label=''
  return self~add(.MLImagePolygon~new(points,style,evidence,space,semanticKey,label),layerName)
::method rectangle
  use strict arg x,y,width,height,style,evidence=.nil,space='PIXEL',layerName='overlay',radius=0,semanticKey='',label=''
  return self~add(.MLImageRectangle~new(x,y,width,height,style,evidence,space,radius,semanticKey,label),layerName)
::method ellipse
  use strict arg cx,cy,rx,ry,style,evidence=.nil,space='PIXEL',layerName='overlay',semanticKey='',label=''
  return self~add(.MLImageEllipse~new(cx,cy,rx,ry,style,evidence,space,semanticKey,label),layerName)
::method circle
  use strict arg cx,cy,radius,style,evidence=.nil,space='PIXEL',layerName='overlay',semanticKey='',label=''
  return self~add(.MLImageCircle~new(cx,cy,radius,style,evidence,space,semanticKey,label),layerName)
::method marker
  use strict arg x,y,radius,style,evidence=.nil,space='PIXEL',layerName='overlay',shape='CIRCLE',semanticKey='',label=''
  return self~add(.MLImageMarker~new(x,y,radius,style,evidence,space,shape,semanticKey,label),layerName)
::method text
  use strict arg x,y,text,style,evidence=.nil,space='PIXEL',layerName='overlay',fontSize=12,anchor='START',semanticKey='',label=''
  return self~add(.MLImageText~new(x,y,text,style,evidence,space,fontSize,anchor,semanticKey,label),layerName)
::method putMetadata
  expose _metadata
  use strict arg key,value
  _metadata[key]=value; return value
::method metadata
  expose _metadata
  use strict arg key,default=.nil
  if _metadata~hasIndex(key) then return _metadata[key]
  return default
::method render
  use strict arg renderer,path,options=.nil
  if \renderer~isA(.MLImageRenderer) then raise syntax 88.900 array('image renderer must be MLImageRenderer')
  if options==.nil then options=.MLImageRenderOptions~new
  if \options~isA(.MLImageRenderOptions) then raise syntax 88.900 array('image render options must be MLImageRenderOptions')
  return renderer~render(self,path,options)

::class MLImageRenderer public
::method name; return 'ABSTRACT'
::method supports; use strict arg scene; return .false
::method render; use strict arg scene,path,options=.nil; raise syntax 88.900 array('abstract image renderer cannot render')

::class MLImageRenderers public
::method _registry class private
  expose registry
  if symbol('registry')<>'VAR' then do
    registry=.directory~new; registry['SVG']=.MLImageSvgRenderer~new
  end
  return registry
::method register class
  use strict arg renderer
  if \renderer~isA(.MLImageRenderer) then raise syntax 88.900 array('image renderer registration requires MLImageRenderer')
  r=self~_registry; r[renderer~name~upper]=renderer; return renderer
::method byName class
  use strict arg name
  r=self~_registry; key=name~string~upper
  if \r~hasIndex(key) then raise syntax 88.900 array('unknown image renderer',key)
  return r[key]
::method names class
  r=self~_registry; out=.array~new; do k over r; out~append(k); end; out~sort; return out

::class MLImageSvgRenderer subclass MLImageRenderer public
::method name; return 'SVG'
::method supports; use strict arg scene; return scene~isA(.MLImageScene)
::method render
  use strict arg scene,path,options=.nil
  if options==.nil then options=.MLImageRenderOptions~new
  if \self~supports(scene) then raise syntax 88.900 array('SVG image renderer requires MLImageScene')
  s=.stream~new(path); rc=s~open('write replace')
  if rc<>'READY:' then raise syntax 88.900 array('unable to open image output',path,rc)
  w=scene~width; h=scene~height; scale=options~scale
  outW=format(w*scale,,0); outH=format(h*scale,,0)
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="'||outW||'" height="'||outH||'" viewBox="0 0 '||w||' '||h||'">')
  s~lineout('<defs><clipPath id="image-bounds"><rect x="0" y="0" width="'||w||'" height="'||h||'"/></clipPath></defs>')
  if options~includeBase then self~writeBase(s,scene~source)
  clip=''; if options~clipToImage then clip=' clip-path="url(#image-bounds)"'
  s~lineout('<g class="image-overlays"'||clip||'>')
  do layer over scene~layers
    if \layer~visible then iterate
    s~lineout('<g class="image-layer" data-layer="'||self~escape(layer~name)||'">')
    do primitive over layer~primitives; self~writePrimitive(s,scene,primitive,layer~opacity); end
    s~lineout('</g>')
  end
  s~lineout('</g>')
  s~lineout('</svg>'); s~close; return path
::method writeBase private
  use strict arg s,source
  w=source~width; h=source~height
  s~lineout('<g class="base-image" shape-rendering="crispEdges">')
  do y=0 to h-1
    x=0
    do while x<w
      c=source~colourAt(x,y); start=x; x=x+1
      do while x<w
        n=source~colourAt(x,y)
        if n~hex<>c~hex | n~a<>c~a then leave
        x=x+1
      end
      attrs=' fill="'||c~hex||'"'
      if c~a<>1 then attrs=attrs||' fill-opacity="'||c~a||'"'
      s~lineout('<rect x="'||start||'" y="'||y||'" width="'||(x-start)||'" height="1"'||attrs||'/>')
    end
  end
  s~lineout('</g>')
::method writePrimitive private
  use strict arg s,scene,p,layerOpacity
  kind=p~kind; style=p~style; attrs=self~styleAttrs(style,layerOpacity); lineAttrs=self~styleAttrs(style,layerOpacity,'NONE')
  if kind='LINE' then do
    a=self~xy(scene,p,p~p1); b=self~xy(scene,p,p~p2)
    s~lineout('<line x1="'||a[1]||'" y1="'||a[2]||'" x2="'||b[1]||'" y2="'||b[2]||'"'||lineAttrs||'/>'); return
  end
  if kind='POLYLINE' | kind='POLYGON' then do
    pts=self~pointsText(scene,p,p~points)
    if kind='POLYLINE' then s~lineout('<polyline points="'||pts||'"'||lineAttrs||'/>')
    else s~lineout('<polygon points="'||pts||'"'||attrs||'/>')
    return
  end
  if kind='RECTANGLE' then do
    a=self~xyRaw(scene,p,p~x,p~y); wh=self~sizeRaw(scene,p,p~width,p~height)
    extra=''; if p~radius>0 then do; rr=self~radiusRaw(scene,p,p~radius); extra=' rx="'||rr||'" ry="'||rr||'"'; end
    s~lineout('<rect x="'||a[1]||'" y="'||a[2]||'" width="'||wh[1]||'" height="'||wh[2]||'"'||extra||attrs||'/>'); return
  end
  if kind='ELLIPSE' then do
    a=self~xyRaw(scene,p,p~cx,p~cy); wh=self~sizeRaw(scene,p,p~rx,p~ry)
    s~lineout('<ellipse cx="'||a[1]||'" cy="'||a[2]||'" rx="'||wh[1]||'" ry="'||wh[2]||'"'||attrs||'/>'); return
  end
  if kind='CIRCLE' then do
    a=self~xyRaw(scene,p,p~cx,p~cy); rr=self~radiusRaw(scene,p,p~radius)
    s~lineout('<circle cx="'||a[1]||'" cy="'||a[2]||'" r="'||rr||'"'||attrs||'/>'); return
  end
  if kind='MARKER' then do
    a=self~xyRaw(scene,p,p~x,p~y); rr=self~radiusRaw(scene,p,p~radius)
    if p~shape='CIRCLE' then s~lineout('<circle cx="'||a[1]||'" cy="'||a[2]||'" r="'||rr||'"'||attrs||'/>')
    else if p~shape='SQUARE' then s~lineout('<rect x="'||(a[1]-rr)||'" y="'||(a[2]-rr)||'" width="'||(2*rr)||'" height="'||(2*rr)||'"'||attrs||'/>')
    else do
      s~lineout('<line x1="'||(a[1]-rr)||'" y1="'||a[2]||'" x2="'||(a[1]+rr)||'" y2="'||a[2]||'"'||lineAttrs||'/>')
      s~lineout('<line x1="'||a[1]||'" y1="'||(a[2]-rr)||'" x2="'||a[1]||'" y2="'||(a[2]+rr)||'"'||lineAttrs||'/>')
    end
    return
  end
  if kind='TEXT' then do
    a=self~xyRaw(scene,p,p~x,p~y); anchor=p~anchor~lower
    s~lineout('<text x="'||a[1]||'" y="'||a[2]||'" font-family="sans-serif" font-size="'||p~fontSize||'" text-anchor="'||anchor||'"'||attrs||'>'||self~escape(p~text)||'</text>'); return
  end
  raise syntax 88.900 array('SVG image renderer does not support primitive',kind)
::method xy private
  use strict arg scene,p,vertex
  return self~xyRaw(scene,p,vertex~x,vertex~y)
::method xyRaw private
  use strict arg scene,p,x,y
  if p~coordinateSpace='NORMALIZED' then return .array~of(x*scene~width,y*scene~height)
  return .array~of(x,y)
::method sizeRaw private
  use strict arg scene,p,w,h
  if p~coordinateSpace='NORMALIZED' then return .array~of(w*scene~width,h*scene~height)
  return .array~of(w,h)
::method radiusRaw private
  use strict arg scene,p,r
  if p~coordinateSpace='NORMALIZED' then return r*min(scene~width,scene~height)
  return r
::method pointsText private
  use strict arg scene,p,points
  text=''; first=.true
  do v over points
    q=self~xy(scene,p,v)
    if \first then text=text||' '
    text=text||q[1]||','||q[2]; first=.false
  end
  return text
::method styleAttrs private
  use strict arg style,layerOpacity=1,fillMode='STYLE'
  attrs=''
  stroke=style~stroke; fill=style~fill; op=style~opacity*layerOpacity
  if stroke==.nil then attrs=attrs||' stroke="none"'
  else do
    attrs=attrs||' stroke="'||stroke~hex||'" stroke-width="'||style~strokeWidth||'" stroke-opacity="'||(stroke~a*op)||'"'
    attrs=attrs||' stroke-linecap="'||style~lineCap~lower||'" stroke-linejoin="'||style~lineJoin~lower||'"'
    if style~dash<>'' then attrs=attrs||' stroke-dasharray="'||self~escape(style~dash)||'"'
  end
  if fillMode='NONE' | fill==.nil then attrs=attrs||' fill="none"'
  else attrs=attrs||' fill="'||fill~hex||'" fill-opacity="'||(fill~a*op)||'" fill-rule="'||style~fillRule~lower||'"'
  return attrs
::method escape private
  use strict arg text
  x=text~string; x=x~changeStr('&','&amp;'); x=x~changeStr('<','&lt;'); x=x~changeStr('>','&gt;'); x=x~changeStr('"','&quot;')
  return x
