/* Optional raster renderer through ooRexx Foreign Runtime + Python Pillow.
 * Semantic image state stays in ooRexx.  Python owns output pixels only.
 */
ignored=.MLImageRenderers~register(.MLImagePillowRenderer~new)

::class MLImagePillowRenderer subclass MLImageRenderer public
::method init
  expose _image _draw _font _builtins _version
  if \.ForeignPython~canImport('PIL.Image') then raise syntax 88.900 array('importable Pillow PIL.Image','not available')
  _image=.ForeignPython~import('PIL.Image')
  _draw=.ForeignPython~import('PIL.ImageDraw')
  _font=.ForeignPython~import('PIL.ImageFont')
  _builtins=.ForeignPython~import('builtins')
  pil=.ForeignPython~import('PIL'); _version=pil~get('__version__'); pil~close
::method name; return 'PILLOW'
::method version; expose _version; return _version
::method supports; use strict arg scene; return scene~isA(.MLImageScene)
::method render
  expose _image _draw _font _builtins
  use strict arg scene,path,options=.nil
  if options==.nil then options=.MLImageRenderOptions~new
  if \self~supports(scene) then raise syntax 88.900 array('Pillow image renderer requires MLImageScene')
  scale=options~scale; w=scene~width; h=scene~height
  nativeSize=self~tuple2(w,h); transparent=self~tuple4(0,0,0,0)
  base=_image~new('RGBA',nativeSize,transparent)
  if options~includeBase then do
    data=.array~new
    do y=0 to h-1
      do x=0 to w-1
        c=scene~source~colourAt(x,y); data~append(self~pyColour(c,1))
      end
    end
    base~putdata(data)
  end
  if scale<>1 then do
    target=self~tuple2(format(w*scale,,0),format(h*scale,,0))
    resized=base~resize(target,0)  /* Pillow Resampling.NEAREST == 0. */
    base~close; base=resized
  end
  do layer over scene~layers
    if \layer~visible then iterate
    overlay=_image~new('RGBA',self~tuple2(format(w*scale,,0),format(h*scale,,0)),transparent)
    draw=_draw~Draw(overlay)
    do p over layer~primitives; self~drawPrimitive(draw,scene,p,layer~opacity,scale); end
    draw~close
    composed=_image~alpha_composite(base,overlay)
    overlay~close; base~close; base=composed
  end
  base~save(path); base~close; return path
::method drawPrimitive private
  expose _font
  use strict arg draw,scene,p,layerOpacity,scale
  style=p~style
  if style~dash<>'' then raise syntax 88.900 array('Pillow renderer does not silently approximate dashed image strokes',style~dash)
  fill=self~pyColourOrNil(style~fill,style~opacity*layerOpacity)
  stroke=self~pyColourOrNil(style~stroke,style~opacity*layerOpacity)
  width=max(1,format(style~strokeWidth*scale,,0))
  kind=p~kind
  if kind='LINE' then do
    pts=.array~of(self~pointTuple(scene,p,p~p1~x,p~p1~y,scale),self~pointTuple(scene,p,p~p2~x,p~p2~y,scale))
    kw=.ForeignPython~keywords; kw~put('fill',stroke); kw~put('width',width)
    draw~line(pts,kw); return
  end
  if kind='POLYLINE' then do
    pts=self~pointTuples(scene,p,p~points,scale); kw=.ForeignPython~keywords; kw~put('fill',stroke); kw~put('width',width)
    if style~lineJoin='ROUND' then kw~put('joint','curve')
    draw~line(pts,kw); return
  end
  if kind='POLYGON' then do
    pts=self~pointTuples(scene,p,p~points,scale); kw=.ForeignPython~keywords
    if fill \== .nil then kw~put('fill',fill)
    if stroke \== .nil then do; kw~put('outline',stroke); kw~put('width',width); end
    draw~polygon(pts,kw); return
  end
  if kind='RECTANGLE' then do
    box=self~boxTuple(scene,p,p~x,p~y,p~x+p~width,p~y+p~height,scale); kw=.ForeignPython~keywords
    if fill \== .nil then kw~put('fill',fill)
    if stroke \== .nil then do; kw~put('outline',stroke); kw~put('width',width); end
    if p~radius>0 then draw~rounded_rectangle(box,self~radius(scene,p,p~radius,scale),kw)
    else draw~rectangle(box,kw)
    return
  end
  if kind='ELLIPSE' then do
    box=self~boxTuple(scene,p,p~cx-p~rx,p~cy-p~ry,p~cx+p~rx,p~cy+p~ry,scale); kw=.ForeignPython~keywords
    if fill \== .nil then kw~put('fill',fill)
    if stroke \== .nil then do; kw~put('outline',stroke); kw~put('width',width); end
    draw~ellipse(box,kw); return
  end
  if kind='CIRCLE' then do
    r=p~radius; box=self~boxTuple(scene,p,p~cx-r,p~cy-r,p~cx+r,p~cy+r,scale); kw=.ForeignPython~keywords
    if fill \== .nil then kw~put('fill',fill)
    if stroke \== .nil then do; kw~put('outline',stroke); kw~put('width',width); end
    draw~ellipse(box,kw); return
  end
  if kind='MARKER' then do
    q=self~mapped(scene,p,p~x,p~y,scale); r=self~radius(scene,p,p~radius,scale)
    if p~shape='CROSS' then do
      kw=.ForeignPython~keywords; kw~put('fill',stroke); kw~put('width',width)
      draw~line(.array~of(self~tuple2(q[1]-r,q[2]),self~tuple2(q[1]+r,q[2])),kw)
      draw~line(.array~of(self~tuple2(q[1],q[2]-r),self~tuple2(q[1],q[2]+r)),kw)
    end
    else do
      box=self~tuple4(q[1]-r,q[2]-r,q[1]+r,q[2]+r); kw=.ForeignPython~keywords
      if fill \== .nil then kw~put('fill',fill)
      if stroke \== .nil then do; kw~put('outline',stroke); kw~put('width',width); end
      if p~shape='SQUARE' then draw~rectangle(box,kw); else draw~ellipse(box,kw)
    end
    return
  end
  if kind='TEXT' then do
    q=self~mapped(scene,p,p~x,p~y,scale); fontkw=.ForeignPython~keywords; fontkw~put('size',max(1,format(p~fontSize*scale,,0)))
    font=_font~load_default(fontkw); kw=.ForeignPython~keywords
    if fill \== .nil then kw~put('fill',fill); else if stroke \== .nil then kw~put('fill',stroke)
    if p~anchor='START' then kw~put('anchor','la'); else if p~anchor='MIDDLE' then kw~put('anchor','ma'); else kw~put('anchor','ra')
    kw~put('font',font); draw~text(self~tuple2(q[1],q[2]),p~text,kw); font~close; return
  end
  raise syntax 88.900 array('Pillow image renderer does not support primitive',kind)
::method mapped private
  use strict arg scene,p,x,y,scale
  if p~coordinateSpace='NORMALIZED' then return .array~of(x*scene~width*scale,y*scene~height*scale)
  return .array~of(x*scale,y*scale)
::method pointTuple private
  use strict arg scene,p,x,y,scale
  q=self~mapped(scene,p,x,y,scale); return self~tuple2(q[1],q[2])
::method pointTuples private
  use strict arg scene,p,points,scale
  out=.array~new; do v over points; out~append(self~pointTuple(scene,p,v~x,v~y,scale)); end; return out
::method boxTuple private
  use strict arg scene,p,x1,y1,x2,y2,scale
  a=self~mapped(scene,p,x1,y1,scale); b=self~mapped(scene,p,x2,y2,scale); return self~tuple4(a[1],a[2],b[1],b[2])
::method radius private
  use strict arg scene,p,r,scale
  if p~coordinateSpace='NORMALIZED' then return r*min(scene~width,scene~height)*scale
  return r*scale
::method pyColourOrNil private
  use strict arg colour,opacity
  if colour==.nil then return .nil
  return self~pyColour(colour,opacity)
::method pyColour private
  use strict arg colour,opacity=1
  a=format(colour~a*opacity*255,,0); if a<0 then a=0; if a>255 then a=255
  return self~tuple4(colour~r,colour~g,colour~b,a)
::method tuple2 private
  expose _builtins
  use strict arg a,b
  return _builtins~tuple(.array~of(a,b))
::method tuple4 private
  expose _builtins
  use strict arg a,b,c,d
  return _builtins~tuple(.array~of(a,b,c,d))
::method uninit
  expose _image _draw _font _builtins
  if symbol('_image')='VAR' then if _image \== .nil then _image~close
  if symbol('_draw')='VAR' then if _draw \== .nil then _draw~close
  if symbol('_font')='VAR' then if _font \== .nil then _font~close
  if symbol('_builtins')='VAR' then if _builtins \== .nil then _builtins~close

::requires 'MLGraphImage.cls'
::requires 'python_foreign.cls'
