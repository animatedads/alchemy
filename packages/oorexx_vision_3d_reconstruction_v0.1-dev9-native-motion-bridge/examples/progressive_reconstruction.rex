/* Synthetic two-view example showing the intended public flow. */
ctx=.MathContext~decimal(30)
grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-10,-10,-10,ctx),1,3)
recon=.Vision3DReconstruction~new(grid,.02)
target=.MathVector3~new(0,0,-5,ctx)
a=.Vision3DRayObservation~new('scene.mp4',1.0,'frame-30',50,50,.MathRay3D~new(.MathVector3~new(-1,0,0,ctx),target-.MathVector3~new(-1,0,0,ctx),ctx),1,'f30:p50,50','target')
b=.Vision3DRayObservation~new('scene.mp4',2.0,'frame-60',50,50,.MathRay3D~new(.MathVector3~new(1,0,0,ctx),target-.MathVector3~new(1,0,0,ctx),ctx),1,'f60:p50,50','target')
tri=recon~triangulate(a,b,'target',1)
say 'status='tri~status 'point='tri~point
region=.VisionRegion~new(40,40,20,20,1.0,2.0)
item=.Vision3DEnhancementItem~new('TARGET-EDGE','DEPTH-UNCERTAINTY',region,1.0,2.0,.55,.9,'target')
item~requireDimensions(320,320)
recon~enqueueEnhancement(item)
req=recon~enhancementQueue~next~asHighResolutionRequest('scene.mp4')
say 'high-resolution request='req~reason req~request~requestedSpatialResolution
::requires 'Vision3DReconstruction.cls'
