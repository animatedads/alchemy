parse arg out
if out='' then out='test_mlimage_pillow.png'
f=0
pixels=.array~new
do y=0 to 11
  do x=0 to 19
    v=format((x/19)*220,,0); pixels~append(.MLImageColour~rgb(v,40+y*8,120))
  end
end
scene=.MLImageScene~new(.MLImageArraySource~new(20,12,pixels),'Pillow image provider')
scene~polygon(.array~of(.array~of(2,2),.array~of(17,2),.array~of(15,10),.array~of(4,9)), -
  .MLImageStyle~strokeFill(.MLImageColour~rgba(255,255,0,.9),.MLImageColour~rgba(255,0,0,.25),1,.8))
scene~line(.array~of(0,11),.array~of(19,0),.MLImageStyle~stroke(.MLImageColour~rgba(0,255,255,.7),1,.9))
scene~marker(10,6,1.5,.MLImageStyle~stroke(.MLImageColour~rgba(255,255,255,.9),1),.nil,'PIXEL','overlay','CROSS')
scene~render(.MLImageRenderers~byName('PILLOW'),out,.MLImageRenderOptions~new(8))
call check stream(out,'c','query size')>100,'Pillow output is non-empty'
call check .MLImageRenderers~byName('PILLOW')~version<>'','Pillow provider reports version'
if f=0 then do; say 'PASS MLGraph Pillow image 2 assertions'; exit 0; end
say 'FAIL MLGraph Pillow image failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphPillow.cls'
