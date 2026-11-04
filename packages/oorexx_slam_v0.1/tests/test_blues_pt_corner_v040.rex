/* Power SLAM v0.40 — Blues Point rooftop-camera geometry regression.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6.
 * Same tower catalogue and model geometry used by native renderer.
 * Model base assumed at 0m, NOT independently surveyed AHD.
 */
checks=0
model=.HarbourOcclusionPanorama~new
scene=model~scene
tower=.HarbourBluesPointTower~catalogue
centre=scene~local(tower['LAT'],tower['LON'])
cam=model~siteCamera('BLUES_PT')
halfE=tower['FOOTPRINT_ALONG_M']/2
halfS=tower['FOOTPRINT_ACROSS_M']/2
call assert abs(cam[1]-(centre[1]+halfE))<0.02,'eastmost roof edge x'
call assert abs(cam[2]-(centre[2]-halfS))<0.02,'southeast roof corner y'
call assert abs(cam[3]-(tower['STRUCTURAL_HEIGHT_M']+2))<0.01,'model roof plus two metres'
call assert cam[1]>centre[1],'camera east of building centre'
call assert cam[2]<centre[2],'camera south of building centre'
call assert abs(cam[3]-85)<0.01,'illustrative base zero yields height 85'
r=model~configure
roof=scene~features['BPT_ROOF']
cam=model~siteCamera('BLUES_PT')
call assert abs(cam[3]-(roof[3]+2))<0.01,'configured rooftop plus two metres'
call assert abs(cam[1]-(roof[1]+halfE))<0.02,'camera east offset from configured rooftop'
call assert abs(cam[2]-(roof[2]-halfS))<0.02,'camera south offset from configured rooftop'
north=model~siteCamera('NORTH_PTZ')
call assert abs(north[3]-79)<0.01,'other PTZ preserved'
say 'PASS' checks 'native Blues Point SE corner qualification checks'
exit 0
assert:
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  checks+=1
  return
::requires 'SlamHarbourOcclusion.cls'
