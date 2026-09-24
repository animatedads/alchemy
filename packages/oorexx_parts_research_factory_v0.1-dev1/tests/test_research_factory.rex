numeric digits 50

/* Five deliberately different offline acceptance cases. */
materials=.array~of('STEEL-8.8-REFERENCE','CU-C110-REFERENCE','OPTICAL-GLASS-GENERIC','HSS-GENERIC','POM-GENERIC')
parts=.array~new

req=makeRequest('bearing-6203-reference','DEEP_GROOVE_BALL_BEARING','6203 bearing')
req~addProperty('bore'); req~addProperty('outsideDiameter'); req~addProperty('width'); req~addMaterialRole('rings'); req~addMaterialRole('balls')
call addMaterials req,materials
candidate=makeCandidate('BEARING-6203-REFERENCE','DEEP_GROOVE_BALL_BEARING','6203 reference',.array~of(prop('BORE','17','mm','STANDARD_DEFINED'),prop('OUTSIDE_DIAMETER','40','mm','STANDARD_DEFINED'),prop('WIDTH','12','mm','STANDARD_DEFINED')),.array~of(role('RINGS','STEEL-8.8-REFERENCE'),role('BALLS','STEEL-8.8-REFERENCE')))
call accept req,candidate,parts

/* Replay the two live response shapes: candidates[] and property/material maps. */
rawCandidate=.directory~new; rawCandidate['partFamily']='FASTENER'; rawCandidate['partDescription']='M3 plain washer'
rawProps=.directory~new; rawProps['bore']=.directory~new; rawProps['bore']['value']=3; rawProps['bore']['unit']='mm'; rawProps['bore']['provenance']='ISO 7089'; rawProps['bore']['confidence']='HIGH'; rawCandidate['properties']=rawProps
rawMat=.directory~new; rawMat['body']=.directory~new; rawMat['body']['materialId']='STEEL-8.8-REFERENCE'; rawMat['body']['provenance']='reference'; rawCandidate['materials']=rawMat
raw=.directory~new; raw['requestId']='bearing-6203-reference'; raw['candidates']=.array~of(rawCandidate)
normalized=.PartResearchValidator~validate(raw,req~value,parts); if normalized['OK']<>.true then call fail 'live response normalization'; if raw['candidate']['id']<> 'AI-BEARING-6203-REFERENCE' then call fail 'normalized candidate id'
if raw['candidate']['properties']~items<>1 then call fail 'normalized property map'; if raw['candidate']['materialRoles']~items<>1 then call fail 'normalized material map'

/* Further live-shape replay: root family/description, categorical materialId,
   compound units, and a bounded numeric range. */
req=makeRequest('sensor-pt100','RTD','PT100 temperature sensor'); req~addProperty('R0'); req~addMaterialRole('element'); call addMaterials req,materials
pt=.directory~new; pt['id']='AI-SENSOR-PT100'; pt['properties']=.directory~new
p=.directory~new; p['value']=100; p['unit']='ohm'; p['provenance']='IEC 60751'; p['confidence']='HIGH'; pt['properties']['R0']=p
p=.directory~new; p['value']='0.00385'; p['unit']='ohm/ohm/°C'; p['provenance']='IEC 60751'; p['confidence']='HIGH'; pt['properties']['temperatureCoefficient']=p
r=.directory~new; r['min']=-200; r['max']=850; p=.directory~new; p['value']=r; p['unit']='°C'; p['provenance']='representative reference'; p['confidence']='MEDIUM'; pt['properties']['operatingRange']=p
pt['materials']=.directory~new; pt['materials']['element']='CU-C110-REFERENCE'
live=.directory~new; live['schema']='parts.research.response/0.1'; live['requestId']=req~value['requestId']; live['status']='ACCEPTED'; live['partFamily']='RTD'; live['partDescription']='PT100 temperature sensor'; live['partCandidate']=pt
outcome=.PartResearchValidator~validate(live,req~value,parts); if \outcome['OK'] then call fail 'PT100 response normalization'; if live['candidate']['family']<>'RTD' then call fail 'root family normalization'; if live['candidate']['materialRoles']~items<>1 then call fail 'string material normalization'

/* A bad model range is rejected, not silently clamped. */
badValue=.directory~new; badValue['min']=10; badValue['max']=-10
badProp=.directory~new; badProp['name']='RANGE'; badProp['value']=badValue; badProp['unit']='°C'; badProp['condition']='UNKNOWN'; badProp['provenance']='ESTIMATED'; badProp['confidence']='UNKNOWN'
badCandidate=makeCandidate('BAD-RANGE','RTD','bad',.array~of(badProp),.array~of(role('ELEMENT','CU-C110-REFERENCE')))
badRange=.directory~new; badRange['schema']='parts.research.response/0.1'; badRange['requestId']=req~value['requestId']; badRange['status']='ACCEPTED'; badRange['candidate']=badCandidate
outcome=.PartResearchValidator~validate(badRange,req~value,parts); if outcome['OK'] then call fail 'accepted inverted range'

req=makeRequest('resistor-1k','RESISTOR','1 kOhm resistor'); req~addProperty('resistance'); req~addMaterialRole('lead'); call addMaterials req,materials
candidate=makeCandidate('RESISTOR-E24-1K','RESISTOR','E24 resistor',.array~of(prop('RESISTANCE','1000','Ohm','ENGINEERING_REFERENCE')),.array~of(role('LEAD','CU-C110-REFERENCE')))
call accept req,candidate,parts

req=makeRequest('laser-diode-650nm','LASER_DIODE','650 nm laser diode'); req~addProperty('wavelength'); req~addMaterialRole('window'); call addMaterials req,materials
candidate=makeCandidate('LASER-DIODE-650NM','LASER_DIODE','Representative laser diode',.array~of(prop('WAVELENGTH','650','nm','MANUFACTURER_SPECIFIC')),.array~of(role('WINDOW','OPTICAL-GLASS-GENERIC')))
call accept req,candidate,parts

req=makeRequest('hss-endmill-6mm','CUTTING_TOOL','6 mm HSS end mill'); req~addProperty('diameter'); req~addMaterialRole('body'); call addMaterials req,materials
candidate=makeCandidate('ENDMILL-6MM-HSS','CUTTING_TOOL','HSS end mill',.array~of(prop('DIAMETER','6','mm','ENGINEERING_REFERENCE')),.array~of(role('BODY','HSS-GENERIC')))
call accept req,candidate,parts

req=makeRequest('obscure-part','UNKNOWN','obscure component'); call addMaterials req,materials
candidate=.directory~new; candidate['id']='OBSCURE-REFERENCE'; candidate['family']='UNKNOWN'; candidate['description']='Obscure component'; candidate['properties']=.array~new; candidate['materialRoles']=.array~new; candidate['provenance']=.array~of('No authoritative source identified')
response=.directory~new; response['schema']='parts.research.response/0.1'; response['requestId']=req~value['requestId']; response['status']='UNKNOWN'; response['candidate']=candidate
response['warnings']=.array~of('No reliable source'); response['missingInformation']=.array~of('all dimensions'); response['confidence']='0';
outcome=.PartResearchValidator~validate(response,req~value,parts); if \outcome['OK'] then call fail 'unknown response rejected'

/* malformed JSON, wrong schema, unknown unit, unresolved material, duplicate ID,
   negative dimension, missing provenance, and prose injection are rejected. */
call rejectMalformed
bad=req~value; bad['existingMaterialIds']=materials; badCandidate=makeCandidate('BAD-UNIT','BAD','bad',.array~of(prop('WIDTH','3','furlong','ESTIMATED')),.array~of(role('BODY','STEEL-8.8-REFERENCE'))); badResponse=makeResponse(bad,badCandidate)
call expectReject badResponse,bad,'unknown unit'
badCandidate=makeCandidate('BAD-MATERIAL','BAD','bad',.array~of(prop('WIDTH','3','mm','ESTIMATED')),.array~of(role('BODY','MADE-UP-MATERIAL'))); call expectReject makeResponse(bad,badCandidate),bad,'unresolved material'
badCandidate=makeCandidate('BAD-NEGATIVE','BAD','bad',.array~of(prop('WIDTH','-3','mm','ESTIMATED')),.array~of(role('BODY','STEEL-8.8-REFERENCE'))); call expectReject makeResponse(bad,badCandidate),bad,'negative dimension'
badCandidate=makeCandidate('BAD-PROSE','BAD','bad',.array~of(prop('WIDTH','3','mm','ESTIMATED')),.array~of(role('BODY','STEEL-8.8-REFERENCE'))); badCandidate['provenance']=.array~new; call expectReject makeResponse(bad,badCandidate),bad,'provenance'
badCandidate=makeCandidate('BEARING-6203-REFERENCE','BAD','bad',.array~of(prop('WIDTH','3','mm','ESTIMATED')),.array~of(role('BODY','STEEL-8.8-REFERENCE'))); outcome=.PartResearchValidator~validate(makeResponse(bad,badCandidate),bad,parts); if outcome['OK'] then call fail 'accepted duplicate'

cache=.PartResearchCache~new; cache~put('k1',req~toJSON,.JSON~toJSON(makeResponse(req~value,candidate)),'ACCEPTED'); if cache~get('k1')=.nil then call fail 'cache replay'
budget=.PartResearchBudget~new(70,68); if budget~canSpend(69) then call fail 'budget stop'; budget~charge(5); if budget~spent<>5 then call fail 'budget charge'
say 'PASS parts research factory five-case acceptance' parts~items 'accepted candidates'
exit 0

makeRequest: procedure
  parse arg id,family,description
  return .PartResearchRequest~new(id,'CREATE_PART_CANDIDATE',family,description)
addMaterials: procedure
  use arg request,ids
  do id over ids; request~ADDEXISTINGMATERIALID(id); end
return
prop: procedure
  parse arg name,value,unit,provenance
  d=.directory~new; d['name']=name; d['value']=value; d['unit']=unit; d['condition']='20 C'; d['provenance']=provenance; d['confidence']='0.8'; return d
role: procedure
  parse arg roleName,materialId
  d=.directory~new; d['role']=roleName; d['materialId']=materialId; d['provenance']='existing Materials catalogue'; return d
makeCandidate: procedure
  use arg id,family,description,properties,roles
  d=.directory~new; d['id']=id; d['family']=family; d['description']=description; d['modelGrade']='ENGINEERING_REFERENCE'; d['properties']=properties; d['materialRoles']=roles; d['geometry']=.directory~new; d['ratings']=.array~new; d['provenance']=.array~of('offline acceptance fixture'); d['uncertainties']=.array~new; return d
makeResponse: procedure
  use arg request,candidate
  d=.directory~new; d['schema']='parts.research.response/0.1'; d['requestId']=request['requestId']; d['status']='ACCEPTED'; d['candidate']=candidate; d['warnings']=.array~new; d['missingInformation']=.array~new; d['confidence']='0.8'; return d
accept: procedure expose parts
  use arg request,candidate,parts
  response=makeResponse(request~value,candidate)
  outcome=.PartResearchValidator~validate(response,request~value,parts)
  if \outcome['OK'] then call fail 'candidate rejected'
  parts~append(candidate['id'])
  source=.PartResearchGenerator~render(candidate); if source~pos('::method')=0 then call fail 'generator'
  return
expectReject: procedure
  use arg response,request,expected
  outcome=.PartResearchValidator~validate(response,request,.array~new); if outcome['OK'] then call fail 'accepted '||expected
  return
rejectMalformed:
  signal on syntax name malformed
  ignore=.PartResearchResponse~fromJSON('{not-json')
  signal off syntax; call fail 'malformed JSON accepted'; return
malformed:
  signal off syntax; return
fail: procedure
  parse arg message; say 'FAIL:' message; exit 1

::requires '../src/PartResearchContract.cls'
