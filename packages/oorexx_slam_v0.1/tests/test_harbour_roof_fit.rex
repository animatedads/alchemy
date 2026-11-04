/* Power SLAM v0.8 footprint-aware multistart regression. Uses genuine ooRexx. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
f=.HarbourPerspectiveFit~new
checks=0
p=f~cameraPolygon
b=p~bounds
call test p~provenance == 'OVERSIZED_BUILDING_AREA_HYPOTHESIS_NOT_SURVEYED', 'default envelope explicitly provisional'
call test b[2]-b[1]=80 & b[4]-b[3]=64, 'XY search envelope both axes larger than old 20-m square'
c=f~initialCamera
call test p~contains(c[1],c[2]), 'index centre admitted'
call test p~contains(c[1]+25,c[2]-20), 'east and rearward position admitted'
call test p~contains(c[1]-25,c[2]+20), 'west and forward position admitted'
call test \p~contains(c[1]+50,c[2]), 'outside envelope rejected'
call test \p~contains(c[1],c[2]+40), 'north of envelope rejected'
poly=.HarbourCameraPolygon~new(.array~of(.array~of(0,0),.array~of(40,0),.array~of(15,35)), 'TRIANGLE_TEST')
call test poly~contains(15,10), 'custom triangle contains valid interior'
call test \poly~contains(35,30), 'custom triangle refuses bounding box corner'
call test poly~contains(0,0), 'custom polygon admits vertex'
call test poly~provenance == 'TRIANGLE_TEST', 'caller provenance preserved'
/* Synthetic perspective input proves independent X and Y recoverability in
   a non-survey experiment. The model creates the synthetic image and the fit
   has not been given the generating position. */
truePose=c~copy
truePose[1]=c[1]+18
truePose[2]=c[2]-18
truePose[3]=27.5
truePose[4]=4.2
truePose[5]=0.1
truePose[6]=2500
obs=.array~new
do id over .array~of('S_TOP','N_TOP','S_DECK','N_DECK','CAHILL_W','CAHILL_E','ARCH_CROWN')
  q=f~project(f~world(id),truePose)
  call test q\==.nil, 'synthetic control visible' id
  obs~append(.array~of(id,q[1],q[2],3))
end
r=f~fit(obs,c,25,29)
best=r['POSE']
say 'SYNTHETIC XY: truth' truePose[1] truePose[2] 'fit' best[1] best[2]
say 'SYNTHETIC XYZ: fit' best[1] best[2] best[3] 'chi2' r['CHI2']
call test r['SEEDS']=18, '18 distinct footprint multistarts'
call test p~contains(best[1],best[2]), 'fitted camera inside footprint'
call test abs(best[1]-c[1])>10 & abs(best[2]-c[2])>10, 'fit searches beyond former 10-m XY limits'
call test abs(best[1]-truePose[1])<5 & abs(best[2]-truePose[2])<5, 'synthetic X/Y recovered within five metres'
call test abs(best[3]-truePose[3])<5, 'synthetic camera height within five metres'
call test r['CHI2']<10, 'reprojection chi2 small for internally consistent synthetic data'
say 'FOOTPRINT FIT TEST:' checks 'checks PASS'
exit 0
test:
  use arg good,label
  if \good then do
    say 'FAIL' label
    exit 2
  end
  checks+=1
  say 'PASS' label
  return
::requires 'SlamHarbourPerspectiveFit.cls'