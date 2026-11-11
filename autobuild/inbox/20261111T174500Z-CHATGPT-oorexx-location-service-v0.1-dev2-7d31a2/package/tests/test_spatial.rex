/* Native ooRexx synthetic world tests. */
r=.LocationJurisdictionIndex~new
r~add(.LocationJurisdiction~new('country-a',.LocationRect~new('EPSG:4326',0,0,1,2),'2000','','fixture','sha:a','test'))
r~add(.LocationJurisdiction~new('overlay',.LocationRect~new('EPSG:4326',0.3,0.3,0.7,1.7),'2010','','fixture','sha:b','test'))
call verify r~at('EPSG:4326',0.5,1,'2026')~matches~items=2,'overlap'
call verify r~at('EPSG:4326',0.5,1,'2005')~matches~items=1,'historical overlay'
call verify r~at('EPSG:4326',0.5,1,'')~status=='UNKNOWN_TIME','unknown time'
call verify r~at('EPSG:27700',0.5,1,'2026')~status=='UNSUPPORTED_CRS','no silent transform'
call verify r~at('EPSG:4326',0.5,1,'2026')~providers~items=2,'provenance'
call verify r~at('EPSG:4326',4,1,'2026')~status=='NOT_FOUND','no invented coverage'
say 'LOCATION SPATIAL: 6/6 PASS (synthetic)'
exit 0
verify: procedure
  parse arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 2
  end
  return
::requires 'LocationSpatial.cls'
