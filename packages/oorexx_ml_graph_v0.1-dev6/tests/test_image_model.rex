f=0
pixels=.array~of(.MLImageColour~black,.MLImageColour~white,.MLImageColour~red,.MLImageColour~blue)
src=.MLImageArraySource~new(2,2,pixels,'raw-evidence')
scene=.MLImageScene~new(src,'overlay model')
call check scene~width=2 & scene~height=2,'scene keeps arbitrary source dimensions'
call check scene~evidence='raw-evidence','scene retains source evidence'

stroke=.MLImageStyle~stroke(.MLImageColour~rgba(255,255,0,.5),2,.75)
fill=.MLImageStyle~strokeFill(.MLImageColour~rgba(0,255,255,.8),.MLImageColour~rgba(255,0,0,.25),1.5,.6)
line=scene~line(.array~of(0,0),.array~of(1,1),stroke,'line-evidence')
poly=scene~polygon(.array~of(.array~of(.1,.1),.array~of(.9,.1),.array~of(.5,.9)),fill,'polygon-evidence','NORMALIZED')
scene~rectangle(0,0,1,1,stroke)
scene~ellipse(1,1,.5,.25,fill)
scene~circle(1,1,.4,fill)
scene~marker(1,0,.2,stroke,.nil,'PIXEL','overlay','CROSS')
scene~text(.5,.5,'A',.MLImageStyle~fill(.MLImageColour~rgba(255,255,255,.8)),.nil,'NORMALIZED','overlay',10,'MIDDLE')
call check scene~layerCount=1 & scene~layer('overlay')~primitiveCount=7,'full primitive family is retained in ordered layer'
call check line~kind='LINE' & line~evidence='line-evidence','line retains evidence'
call check poly~kind='POLYGON' & poly~coordinateSpace='NORMALIZED' & poly~points~items=3,'polygon retains coordinate-space semantics'
call check fill~fill~a=.25 & fill~stroke~a=.8 & fill~opacity=.6,'stroke/fill alpha and style opacity remain separate evidence'
call check .MLImageColour~rgb(1,2,3)~hex='#010203','colour converts deterministically to hex'
copy=scene~layers; copy~append(.MLImageLayer~new('fake'))
call check scene~layerCount=1,'returned layer list cannot mutate scene'
opts=.MLImageRenderOptions~new(4,.true,.true)
call check opts~scale=4 & opts~includeBase & opts~clipToImage,'render scaling is presentation state'
call check .MLImageRenderers~byName('SVG')~name='SVG','reference image renderer is registered'
if f=0 then do; say 'PASS MLGraph image model 10 assertions'; exit 0; end
say 'FAIL MLGraph image model failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphImage.cls'
