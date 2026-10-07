/* Area-scale topology traced from the supplied overlapping aerial screenshots.
   Coordinates are local engineering hypotheses, not OS/Google survey coordinates. */
parse source . . here
root=filespec('location',here)'..'; call directory root

m=.SurveyAreaMap~new('Paisley supplied-photo survey area — evidence map')
/* anchor chain, roughly north/town-centre to south-east residential coverage */
call node m,'CENTRE',0,520,'Paisley Centre','OBSERVED',8
call node m,'ARTS',95,455,'Paisley Arts Centre','OBSERVED',8
call node m,'CANAL',210,330,'Paisley Canal','OBSERVED',10
call node m,'NEILSTON',250,220,'Neilston Road / Co-op','CARTOGRAPHIC',12
call node m,'MORRISONS',320,205,'Morrisons','OBSERVED',10
call node m,'MORRISONS_PETROL',275,225,'Morrisons Petrol Station','OBSERVED',10
call node m,'FALSIDE',250,70,'Falside Road','CARTOGRAPHIC',12
call node m,'BRAIDS',215,5,'Braids Road','CARTOGRAPHIC',12
call node m,'PARK',230,-75,'Park Road','CARTOGRAPHIC',15
call node m,'SAUCEHILL',85,185,'Saucehill Park','OBSERVED',15
call node m,'CHARLESTON',285,155,'Charleston','OBSERVED',18
call node m,'BRODIE',330,-70,'Brodie Park','OBSERVED',15
call node m,'RAH',245,-300,'Royal Alexandra Hospital','OBSERVED',20
call node m,'LOCHFIELD',315,250,'Lochfield Road','CARTOGRAPHIC',18
call node m,'STANLEY',360,-205,'Stanley Road','CARTOGRAPHIC',18
call node m,'GALLOW',105,-300,'Gallow Green Road','CARTOGRAPHIC',20
call node m,'CANAL_ST',70,-120,'Canal Street','CARTOGRAPHIC',18
call node m,'TENNIS',335,55,'Tennis courts','OBSERVED',12
call node m,'ALDI',315,275,'ALDI','OBSERVED',10
call node m,'PRINTERS',300,255,'Printers Place','CARTOGRAPHIC',12
/* town centre roads */
call road m,'HIGH','High Street','-70,545 0,520 85,505 155,500','CARTOGRAPHIC',10
call road m,'NEW','New Street','20,500 65,455 105,405 145,350','CARTOGRAPHIC',10
call road m,'WITHERSPOON','Witherspoon Street','105,405 160,335 205,270','CARTOGRAPHIC',10
call road m,'CAUSEYSIDE','Causeyside Street','155,500 175,430 195,365 210,300','CARTOGRAPHIC',10
call road m,'NEILSTONRD','Neilston Road','210,300 250,245 300,240 350,255','CARTOGRAPHIC',10
call road m,'FALSIDERD','Falside Road','250,220 245,145 250,70 230,-75','CARTOGRAPHIC',12
call road m,'BRAIDSRD','Braids Road','150,15 215,5 285,15','CARTOGRAPHIC',12
call road m,'PARKRD','Park Road','140,-75 230,-75 325,-65 365,-95','CARTOGRAPHIC',15
call road m,'LOCHFIELDRD','Lochfield Road','250,220 285,190 315,250 345,315','CARTOGRAPHIC',18
call road m,'STANLEYRD','Stanley Road','325,-65 345,-130 360,-205 400,-235','CARTOGRAPHIC',18
call road m,'CANALST','Canal Street','210,300 155,210 115,115 85,15 70,-120 80,-220','CARTOGRAPHIC',18
call road m,'GALLOWGREEN','Gallow Green Road','55,-285 105,-300 175,-305 245,-300','CARTOGRAPHIC',20
call road m,'GEORGE','George Street','205,270 255,330 310,385','CARTOGRAPHIC',12
call road m,'STOCK','Stock Street','285,250 285,165 300,90','CARTOGRAPHIC',12
call road m,'GREAT_HAMILTON','Great Hamilton Street','350,255 385,175 395,95','CARTOGRAPHIC',15
call road m,'STOW','Stow Street / Brae','300,205 345,150 395,95','CARTOGRAPHIC',15
/* rail/canal observed in screenshots */
p=.SurveyMapPath~new('RAIL','Paisley Canal rail alignment','RAIL','OBSERVED',12); p~add(195,360); p~add(225,325); p~add(265,300); p~add(315,280); m~addPath(p)
p=.SurveyMapPath~new('WHITE_CART','White Cart Water','WATER','OBSERVED',15); p~add(-70,600); p~add(-35,570); p~add(0,555); m~addPath(p)
out=.SurveyAreaSvg~render(m,'output/paisley_area_map.svg',-90,430,-340,620,1.25,60)
say 'PASS output/paisley_area_map.svg'
exit 0

node: procedure
  use arg m,id,x,y,label,evidence,u
  m~addNode(.SurveyMapNode~new(id,x,y,'ANCHOR',label,evidence,u)); return
road: procedure
  use arg m,id,label,coords,evidence,u
  p=.SurveyMapPath~new(id,label,'ROAD',evidence,u)
  do while coords<>''
    parse var coords pair coords
    parse var pair x ',' y
    p~add(x,y)
  end
  m~addPath(p); return
::requires 'rexx/SurveyAreaMap.cls'
