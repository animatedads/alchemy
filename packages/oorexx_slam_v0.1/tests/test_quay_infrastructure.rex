/* Power SLAM quay infrastructure separate qualification. Does not certify survey. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg output
if output=='' then output='.'
p=.HarbourQuayInfrastructurePanorama~new
checks=0
call check p~scene~boxes~items=27,'25 existing cuboids plus rail and Cahill solids'
call check p~wharves~items=9,'nine existing pier references preserved'
call check p~structures~items=3,'station, Cahill, cafe camera metadata'
c=p~getStructure('CQ_STATION');e=p~getStructure('CAHILL');s=p~getStructure('CAFE_SYDNEY')
call check c['WEST_LAT']=-33.86146 & c['WEST_LON']=151.20980,'exact user west endpoint'
call check c['EAST_LAT']=-33.86127 & c['EAST_LON']=151.21160,'exact user east endpoint'
call check abs(c['LENGTH_M']-167.728)<0.5,'167.7m station baseline independent arithmetic'
call check c['LENGTH_M']>=165 & c['LENGTH_M']<=170,'user expected 165-170m length'
call check c['HORIZONTAL']=='USER_SUPPLIED_ENDPOINTS','endpoint measurements not falsely attributed to survey'
call check \c['SURVEYED_FOOTPRINT'] & \c['SURVEYED_ROOF'],'station geometry not survey certified'
call check c['WIDTH_HEIGHT']=='HYPOTHESIS','station height width labelled hypothesis'
call check c['TRACK_REFERENCE_RL']=8.35,'8.35m eastern track approach documented separately'
call check e['GEOMETRIC_RELATION']=='DIRECTLY_ABOVE_CQ_STATION','road above railway'
call check e['BOTTOM_M_ASL']>c['TOP_M_ASL'],'Cahill road bottom above station top in trial model'
call check e['TOP_M_ASL']=16.5 & e['BOTTOM_M_ASL']=13.5,'working road elevation range'
call check e['SCOPE']=='STATION_SEGMENT_ONLY','not pretending whole expressway ends at platforms'
call check \e['SURVEYED_FOOTPRINT'] & \e['SURVEYED_ROOF'],'road geometry not survey certified'
call check s['ALTITUDE_M_ASL']=25,'Café Sydney camera 25m ASL working correction'
call check s['ALTITUDE_STATUS']=='USER_ESTIMATE_NOT_SURVEYED','25m not mistaken for surveyed roof height'
call check \s['TERRACE_LOCATION_SURVEYED'] & \s['SIGHTLINE_QUALIFIED'],'terrace and sightline uncertain'
call check p~siteCamera('CAFE_SYDNEY')[3]=25,'new Cafe site at 25m ASL'
call check p~siteCamera('CIRCULAR')[3]=25,'legacy Circular label corrected to 25m ASL'
call check p~siteCamera('NORTH_SHORE')[3]=50,'Jeffrey Street candidate preserved at 50m ASL'
call check p~siteCamera('KIRRIBILLI')[3]=50,'Kirribilli comparison preserved at 50m ASL'
call check p~siteCamera('BLUES')[3]=50,'Blues Point camera preserved at 50m ASL'
a=p~scene~features['STATION_W'];b=p~scene~features['STATION_E']
call check a[1]<b[1] & a[2]<b[2],'platform west-east and slight NE slant'
call check abs(p~scene~features['STATION_C'][1]-(a[1]+b[1])/2)<0.0001,'platform centre is endpoint midpoint'
call check p~scene~features['CAHILL_C'][3]>p~scene~features['STATION_C'][3],'Cahill top above station roof'
cc=p~siteCamera('CAFE_SYDNEY')
wc=p~pointAngles(a,cc); ec=p~pointAngles(b,cc)
call check wc[1]>300 & ec[1]<50,'station visible across north (360 seam), not behind viewpoint'
call check wc[2]<0 & ec[2]<0,'platform below camera pitch'
call check p~pointAngles(p~scene~features['CAHILL_C'],cc)[2]>p~pointAngles(p~scene~features['STATION_C'],cc)[2],'Cahill above platform in same sightline'
call check p~scene~features~hasIndex('O') & p~scene~features~hasIndex('T'),'opera and Salesforce reference points retained'
call check p~scene~features~hasIndex('CQ2') & p~scene~features~hasIndex('WB89'),'quay and Walsh pier points retained'
file=output || '/cafe_sydney_quay_360.svg'
p~render('CAFE_SYDNEY',file)
svg=charin(file,1,chars(file));call stream file,'C','CLOSE'
call check svg~left(4)=='<svg' & svg~strip('T','0a'x)~right(6)=='</svg>','model SVG root complete'
call check occurrences(svg,'<polygon ')=486,'27 cuboids x 6 faces x 3 wrap copies'
call check lastpos('<polygon ',svg)<lastpos('</svg>',svg),'all cuboids inside SVG root'
call check pos('25 m ASL',svg)>0,'Café Sydney height emitted by model'
call check pos('STATION_W',svg)>0 & pos('STATION_E',svg)>0,'station ends annotated from 3D scene'
call check pos('CAHILL_C',svg)>0,'Cahill top marked from 3D scene'
call check pos('Power SLAM',svg)>0 & pos('Opera box',svg)>0,'original model geometry still annotated'
file2=output || '/north_shore_quay_360.svg'
p~render('NORTH_SHORE',file2)
svg2=charin(file2,1,chars(file2));call stream file2,'C','CLOSE'
call check pos('50 m ASL',svg2)>0 & pos('STATION_W',svg2)>0,'north shore stays at 50m and gains station geometry'
say 'POWER SLAM QUAY INFRASTRUCTURE QUALIFICATION: PASS ('||checks||' checks)'
exit 0
occurrences: procedure
 use arg s,needle
 n=0
 do forever
  i=pos(needle,s)
  if i=0 then leave
  n+=1;s=s~substr(i+needle~length)
 end
 return n
check: procedure expose checks
 use arg ok,label
 checks+=1
 if ok then say 'PASS' label
 else do
  say 'FAIL' label
  exit 1
 end
 return
::requires 'SlamHarbourQuayInfrastructure.cls'
