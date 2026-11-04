/* Native ooRexx tests: Sydney Harbour Bridge masonry/deck continuity. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
p=.HarbourQuayInfrastructurePanorama~new
s=p~scene
pBefore=s~boxes~items
roof=.HarbourBridgeRoofPins~apply(s)
call check roof['STATUS']=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED','roofpin geometry source retained'
call check s~boxes~items=pBefore,'roofpin replacement does not change old box count'
call check s~features['S_DECK'][3]=50,'old scene had z50 proxy; regression recorded'
fixed=.HarbourBridgeVertical~apply(s)
call check fixed['STATUS']=='CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED','provisional correction provenance explicit'
call check fixed['CORRECTED_BOXES']=pBefore+2,'new scene adds two abutment boxes'
call check fixed['DECK_SURFACE_M']=49,'deck surface reference approx 49m'
call check fixed['PYLON_TOP_M']=89,'pylon roof top 89m'
call check fixed['ABUTMENT_BASE_M']=5.5,'abutment ground level provisional 5.5m'
call check s~features['S_DECK'][3]=49,'south deck reference corrected'
call check s~features['N_DECK'][3]=49,'north deck reference corrected'
call check s~features['D'][3]=49,'central deck reference corrected'
call check s~features['NW_DECK_PROXY'][3]=49,'NW deck proxy corrected'
call check s~features['SE_DECK_PROXY'][3]=49,'SE deck proxy corrected'
call check s~features['ABUTMENT_S_BASE'][3]=5.5,'southern abutment below deck'
call check s~features['ABUTMENT_N_TOP'][3]=49,'northern abutment meets road'
props=.HarbourBridgeVertical~levels
call check props['DECK_WIDTH_M']=49,'49m width is not deck altitude'
call check props['ABUTMENT_ACROSS_APPROX_M']>props['DECK_WIDTH_M'],'masonry abutment spans beyond deck edges'
call check props['ABUTMENT_ALONG_APPROX_M']=49,'base approximate length retained'
call check props['PYLON_TOP_M']>props['DECK_SURFACE_APPROX_M'],'upper tower extends above road'
numAbut=0;numPylon=0;numDeck=0
reduced=0
lower=-999;upper=-999;deckLow=-999;deckHigh=-999
pylonLow=999;pylonHigh=-999
SAbut=.nil;NAbut=.nil
roofPts=.HarbourBridgeRoofPins~localCoordinates(s)
do box over s~boxes
  id=box[1];vz=box[2]
  lowest=999999;highest=-999999
  do j=1 to vz~items
    lowest=min(lowest,vz[j][3]);highest=max(highest,vz[j][3])
  end
  select
    when id=='ABUTMENT_S' then do
      numAbut+=1;SAbut=box;lower=lowest;upper=highest
    end
    when id=='ABUTMENT_N' then do
      numAbut+=1;NAbut=box
      call check lowest=5.5 & highest=49,'north abutment lower base meets deck top'
    end
    when id=='DECK' then do
      numDeck+=1;deckLow=lowest;deckHigh=highest
    end
    when id=='PYLON_TOWER_PHOTO' then do
      numPylon+=1;pylonLow=min(pylonLow,lowest);pylonHigh=max(pylonHigh,highest)
      call check lowest=49 & highest=89,'individual upper tower starts on deck and reaches 89'
    end
    otherwise reduced+=1
  end
end
call check numAbut=2,'two physical masonry abutments included'
call check numPylon=4,'all four upper pylons included'
call check numDeck=1,'one model deck exists'
call check lower=5.5 & upper=49,'south abutment continuous to road'
call check deckLow=46 & deckHigh=49,'bridge deck occupies z46..49'
call check deckHigh=upper,'deck surface exactly touches masonry abutment top'
call check pylonLow=upper,'upper four towers meet lower abutment at z49'
call check pylonHigh=89,'upper towers reach official crown height'
call check reduced=pBefore-5,'all non-bridge geometry preserved'
call check abs(s~features['S'][3]-89)<0.001,'pylon top reference remains 89'
call check abs(s~features['ARCH_CROWN'][3]-134)<0.001,'arch crown reference remains 134 (curve unmodelled)'
call check SAbut\==.nil & NAbut\==.nil,'both lower solids geolocated'
call check s~features['ABUTMENT_S_TOP'][3]=s~features['S_DECK'][3],'south abutment and roadway connected'
call check s~features['ABUTMENT_N_TOP'][3]=s~features['N_DECK'][3],'north abutment and roadway connected'
say 'BRIDGE VERTICAL CONTINUITY PASS' checks 'checks, model boxes' s~boxes~items
exit 0
check:
  use arg ok,label
  if \ok then do
    say 'FAIL:' label
    exit 3
  end
  checks+=1
  return
::requires 'SlamHarbourQuayInfrastructure.cls'
::requires 'SlamHarbourBridgeVertical.cls'