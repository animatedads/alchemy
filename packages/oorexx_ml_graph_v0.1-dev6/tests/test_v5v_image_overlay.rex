parse arg out
if out='' then out='test_v5v_overlay.svg'
f=0
/* Deliberately odd dimensions: no 55x73 / 47x84 assumption belongs here. */
w=37; h=23
r=.array~of(0,80,170,255); g=.array~of(0,140,60,255); b=.array~of(20,40,220,255)
model=.VisionColourModel~new(r,g,b)
surface=.VisionSurface~new(w,h,2,4,model)
surface~sourceRef='v5v://qualification/arbitrary'; surface~timestamp='2026-09-23T08:00:00Z'; surface~generation=7
do y=0 to h-1
  do x=0 to w-1
    value=((x%9)+(y%7))//4
    surface~put(x,y,value)
  end
end
scene=.MLImageScene~forVisionSurface(surface,'V5V arbitrary-size overlay')
scene~putMetadata('semanticSource','VisionSurface')
red=.MLImageColour~rgba(255,0,0,.75); yellow=.MLImageColour~rgba(255,255,0,.9); cyan=.MLImageColour~rgba(0,255,255,.28)
scene~line(.array~of(2,3),.array~of(34,19),.MLImageStyle~stroke(red,1.2,.8),'line-evidence')
scene~polygon(.array~of(.array~of(8,5),.array~of(29,4),.array~of(32,17),.array~of(11,19)),.MLImageStyle~strokeFill(yellow,cyan,.8,.9),'polygon-evidence')
scene~rectangle(.08,.1,.28,.35,.MLImageStyle~stroke(.MLImageColour~rgba(0,255,0,.8),.5),.nil,'NORMALIZED')
scene~circle(19,11,4,.MLImageStyle~strokeFill(.MLImageColour~rgba(255,255,255,.9),.MLImageColour~rgba(0,0,0,.2),.6))
scene~render(.MLImageRenderers~byName('SVG'),out,.MLImageRenderOptions~new(10))
call check scene~width=w & scene~height=h,'VisionSurface arbitrary dimensions are preserved'
call check scene~source~sourceKind='VISION_SURFACE','VisionSurface adapter is explicit'
call check scene~source~surface==surface & scene~evidence==surface,'original VisionSurface remains retained evidence'
/* Exact RGB mapping is checked explicitly rather than through renderer output. */
c=scene~source~colourAt(5,4); rgb=model~colour(surface~at(5,4))
call check c~r=rgb[1] & c~g=rgb[2] & c~b=rgb[3],'V5V indexed colour model is consumed without replacing source evidence'
text=slurp(out)
call check text~pos('viewBox="0 0 37 23"')>0,'reference renderer uses exact V5V surface extent'
call check text~pos('stroke-opacity="0.600"')>0,'line transparency is preserved'
call check text~pos('fill-opacity="0.252"')>0,'polygon transparency is preserved'
call check surface~sourceRef='v5v://qualification/arbitrary' & surface~generation=7,'rendering does not mutate Vision provenance'
if f=0 then do; say 'PASS MLGraph V5V image overlay 8 assertions'; exit 0; end
say 'FAIL MLGraph V5V image overlay failures='f; exit 1
slurp: procedure
  parse arg path
  size=stream(path,'c','query size'); s=.stream~new(path); s~open('read'); t=s~charin(1,size); s~close; return t
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphImage.cls'
::requires 'Vision.cls'
