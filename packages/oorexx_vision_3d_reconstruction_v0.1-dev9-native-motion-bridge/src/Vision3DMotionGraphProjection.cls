/* dev7 diagnostic projection to ooRexx ML Graph dev6.
 * Rendering is presentation only; it never modifies Vision evidence.
 */
::class VisionCameraMotionOverlayProjector public
::method scene
  use strict arg surface,motionEvidence,title='camera motion'
  scene=.MLImageScene~forVisionSurface(surface,title)
  vectorStyle=.MLImageStyle~stroke(.MLImageColour~cyan,1)
  lineStyle=.MLImageStyle~stroke(.MLImageColour~yellow,1)
  textStyle=.MLImageStyle~fill(.MLImageColour~white)
  do v over motionEvidence~motionVectors
    p1=.array~of(v~x,v~y); p2=.array~of(v~x+v~dx,v~y+v~dy)
    scene~line(p1,p2,vectorStyle,v,'PIXEL','motion',v~itemId,'motion-vector',v~itemId)
    scene~marker(v~x+v~dx,v~y+v~dy,1.5,vectorStyle,v,'PIXEL','motion','CIRCLE',v~itemId)
  end
  y=10
  scene~text(3,y,'frame '||motionEvidence~frameIndex,textStyle,motionEvidence,'PIXEL','status',8,'START','frame')
  y=y+10
  scene~text(3,y,'dx='||format(motionEvidence~dx,,2)||' dy='||format(motionEvidence~dy,,2),textStyle,motionEvidence,'PIXEL','status',8,'START','drift')
  return scene
::requires 'MLGraphImage.cls'
::requires 'Vision3DCameraPath.cls'
