/* Contract smoke for selective high-resolution request. */
region=.VisionRegion~new(10,20,30,40)
r=.VisionHighResolutionRequest~new('storage:source-video',region,12.5,13.0,'LINE_EVIDENCE')
r~requireDimensions(640,360)
if r~asRegionRequest~requestedSpatialResolution \== '640x360' then do
  say 'FAIL resolution'; exit 1
end
if r~asRegionRequest~purpose \== 'LINE_EVIDENCE' then do
  say 'FAIL purpose'; exit 1
end
say 'PASS high-resolution request contract'
::requires '../src/VisionHighResolutionRequest.cls'
