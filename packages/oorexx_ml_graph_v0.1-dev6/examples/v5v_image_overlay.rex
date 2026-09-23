/* Technical overlay on an arbitrary-size VisionSurface.
 * Run with REXX_PATH including ooRexx Vision dev14 src.
 */
parse arg out
if out='' then out='v5v_image_overlay.svg'
w=160; h=90
r=.array~of(0,34,78,126,178,225,255,244)
g=.array~of(0,52,110,160,204,238,255,206)
b=.array~of(12,30,65,105,148,194,235,255)
model=.VisionColourModel~new(r,g,b)
surface=.VisionSurface~new(w,h,3,8,model)
surface~sourceRef='v5v://example/synthetic'; surface~generation=1
do y=0 to h-1
  do x=0 to w-1
    /* Synthetic indexed field purely to make overlay geometry visible. */
    surface~put(x,y,((x%31)+(y%23))//8)
  end
end
scene=.MLImageScene~forVisionSurface(surface,'Vision/V5V technical overlay')
geometry=.MLImageLayer~new('geometry'); scene~addLayer(geometry)
measure=.MLImageLayer~new('measurement'); scene~addLayer(measure)

outline=.MLImageStyle~stroke(.MLImageColour~rgba(255,255,0,.9),1.2,.95)
region=.MLImageStyle~strokeFill(.MLImageColour~rgba(255,0,0,.9),.MLImageColour~rgba(255,0,0,.16),1.1,.9)
axis=.MLImageStyle~stroke(.MLImageColour~rgba(0,255,255,.85),.9,.9)
label=.MLImageStyle~fill(.MLImageColour~rgba(255,255,255,.9))

scene~polygon(.array~of(.array~of(26,18),.array~of(124,15),.array~of(139,68),.array~of(38,75)),region,'candidate-region','PIXEL','geometry','region')
scene~polyline(.array~of(.array~of(12,77),.array~of(42,61),.array~of(76,54),.array~of(111,42),.array~of(150,31)),outline,'line-assessment','PIXEL','geometry','continuity')
scene~line(.array~of(20,45),.array~of(145,45),axis,'horizontal-measure','PIXEL','measurement')
scene~line(.array~of(80,8),.array~of(80,83),axis,'vertical-measure','PIXEL','measurement')
scene~rectangle(.08,.10,.22,.28,outline,'normalized-aoi','NORMALIZED','geometry',2)
scene~ellipse(112,47,16,10,region,'ellipse-evidence','PIXEL','geometry')
scene~circle(52,40,8,outline,'circle-evidence','PIXEL','geometry')
scene~marker(80,45,4,axis,'intersection','PIXEL','measurement','CROSS')
scene~text(.5,.08,'overlay coordinates remain source evidence',label,.nil,'NORMALIZED','measurement',6,'MIDDLE')
scene~render(.MLImageRenderers~byName('SVG'),out,.MLImageRenderOptions~new(5))
say out
::requires 'MLGraphImage.cls'
::requires 'Vision.cls'
