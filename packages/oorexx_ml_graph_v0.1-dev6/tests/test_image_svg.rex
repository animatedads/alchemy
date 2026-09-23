parse arg out
if out='' then out='test_mlimage.svg'
f=0
pixels=.array~new
colors=.array~of(.MLImageColour~rgb(20,30,40),.MLImageColour~rgb(70,80,90),.MLImageColour~rgb(120,130,140))
do y=0 to 4
  do x=0 to 6; pixels~append(colors[1+((x+y)//3)]); end
end
scene=.MLImageScene~new(.MLImageArraySource~new(7,5,pixels),'SVG primitive qualification')
lineStyle=.MLImageStyle~stroke(.MLImageColour~rgba(255,0,0,.6),.35,.8)
polyStyle=.MLImageStyle~strokeFill(.MLImageColour~rgba(255,255,0,.9),.MLImageColour~rgba(0,255,255,.25),.25,.75)
scene~line(.array~of(0,0),.array~of(6,4),lineStyle)
scene~polyline(.array~of(.array~of(0,4),.array~of(3,1),.array~of(6,4)),lineStyle)
scene~polygon(.array~of(.array~of(1,1),.array~of(5,1),.array~of(3,4)),polyStyle)
scene~rectangle(1,1,2,2,polyStyle)
scene~ellipse(4,2,1,.7,polyStyle)
scene~circle(5.5,3.5,.6,polyStyle)
scene~marker(3,2,.4,lineStyle,.nil,'PIXEL','overlay','CROSS')
scene~text(.5,.15,'evidence',.MLImageStyle~fill(.MLImageColour~rgba(255,255,255,.8)),.nil,'NORMALIZED','overlay',.4,'MIDDLE')
scene~render(.MLImageRenderers~byName('SVG'),out,.MLImageRenderOptions~new(20))
text=slurp(out)
call check stream(out,'c','query size')>1000,'SVG output is non-empty'
call check text~pos('width="140"')>0 & text~pos('height="100"')>0,'render scale changes presentation dimensions only'
call check text~pos('viewBox="0 0 7 5"')>0,'SVG coordinates remain source-image coordinates'
call check text~pos('fill-opacity="0.1875"')>0,'fill alpha composes colour alpha, style opacity and layer opacity'
call check text~pos('<polygon ')>0 & text~pos('<polyline ')>0 & text~pos('<ellipse ')>0 & text~pos('<circle ')>0,'shape primitives are emitted'
call check text~pos('clip-path="url(#image-bounds)"')>0,'overlays are clipped to source image by default'
if f=0 then do; say 'PASS MLGraph image SVG 6 assertions'; exit 0; end
say 'FAIL MLGraph image SVG failures='f; exit 1
slurp: procedure
  parse arg path
  size=stream(path,'c','query size'); s=.stream~new(path); s~open('read'); t=s~charin(1,size); s~close; return t
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphImage.cls'
