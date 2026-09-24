/* Provider-neutral parts.research/0.1 interchange and validation support. */

::class PartResearchRequest public
::attribute value get

::method init
  expose value
  use strict arg requestId, task='CREATE_PART_CANDIDATE', family, description
  value=.directory~new
  value['schema']='parts.research.request/0.1'
  value['requestId']=requestId
  value['task']=task
  value['partFamily']=family
  value['partDescription']=description
  value['requestedProperties']=.array~new
  value['requestedGeometry']=.array~new
  value['requestedMaterialRoles']=.array~new
  value['targetModelGrade']='ENGINEERING_REFERENCE'
  value['existingMaterialIds']=.array~new
  value['existingPartIds']=.array~new
  value['unitsPolicy']='SI_WITH_ENGINEERING_DISPLAY'
  value['provenancePolicy']='NO_UNATTRIBUTED_PRECISION'
  value['constraints']=.directory~new

::method addProperty
  expose value
  use strict arg name
  value['requestedProperties']~append(name)
  return self

::method addGeometry
  expose value
  use strict arg name
  value['requestedGeometry']~append(name)
  return self

::method addMaterialRole
  expose value
  use strict arg role
  value['requestedMaterialRoles']~append(role)
  return self

::method addExistingMaterialId
  expose value
  use strict arg materialId
  value['existingMaterialIds']~append(materialId)
  return self

::method addPartId
  expose value
  use strict arg partId
  value['existingPartIds']~append(partId)
  return self

::method toJSON
  expose value
  return .JSON~toJSON(value)

::class PartResearchResponse public
::attribute value get

::method init
  expose value
  use strict arg valueArg
  value=valueArg

::method fromJSON class
  use strict arg text
  return self~new(.JSON~fromJSON(text))

::method toJSON
  expose value
  return .JSON~toJSON(value)

::method field
  expose value
  use strict arg name
  if \value~hasIndex(name) then return .nil
  return value[name]

::class PartResearchValidator public

::method validate class
  use strict arg response, request, existingPartIds=.nil
  if existingPartIds=.nil then existingPartIds=.array~new
  outcome=.directory~new; outcome['OK']=.true; outcome['ERRORS']=.array~new
  if response=.nil then return self~error(outcome,'response is missing')
  if \response~hasIndex('schema') then return self~error(outcome,'missing response schema')
  if response['schema']<>'parts.research.response/0.1' then return self~error(outcome,'wrong response schema')
  if \response~hasIndex('requestId') then return self~error(outcome,'missing response requestId')
  if response['requestId']<>request['requestId'] then return self~error(outcome,'requestId mismatch')
  if \response~hasIndex('status') then return self~error(outcome,'missing response status')
  status=response['status']~string~upper
  if status<>'ACCEPTED' & status<>'PARTIAL' & status<>'UNKNOWN' then return self~error(outcome,'invalid response status')
  if status='UNKNOWN' then return outcome
  if \response~hasIndex('candidate') then return self~error(outcome,'candidate missing')
  candidate=response['candidate']
  if \candidate~hasIndex('id') then return self~error(outcome,'candidate id missing')
  if candidate['id']='' then return self~error(outcome,'candidate id empty')
  do known over existingPartIds
    if known=candidate['id'] then return self~error(outcome,'duplicate Part ID')
  end
  if \candidate~hasIndex('family') then return self~error(outcome,'candidate family missing')
  if \candidate~hasIndex('properties') then return self~error(outcome,'candidate properties missing')
  if \candidate~hasIndex('materialRoles') then return self~error(outcome,'candidate materialRoles missing')
  do property over candidate['properties']
    if \property~hasIndex('name') then return self~error(outcome,'property name missing')
    if \property~hasIndex('value') then return self~error(outcome,'property value missing')
    if \property~hasIndex('unit') then return self~error(outcome,'property unit missing')
    if property['unit']='' then return self~error(outcome,'property unit empty')
    if \self~knownUnit(property['unit']) then return self~error(outcome,'unknown unit '||property['unit'])
    if \property~hasIndex('provenance') then return self~error(outcome,'property provenance missing')
    if \property~hasIndex('confidence') then return self~error(outcome,'property confidence missing')
    if property['value']~datatype('N') & property['value']<0 & self~dimensionName(property['name']) then return self~error(outcome,'negative dimension')
  end
  do role over candidate['materialRoles']
    if \role~hasIndex('role') | \role~hasIndex('materialId') then return self~error(outcome,'invalid material role')
    if role['materialId']='' then return self~error(outcome,'empty material ID')
    found=.false
    do materialId over request['existingMaterialIds']
      if materialId=role['materialId'] then found=.true
    end
    if \found then return self~error(outcome,'unresolved material ID '||role['materialId'])
  end
  if \candidate~hasIndex('provenance') then return self~error(outcome,'candidate provenance missing')
  if candidate['provenance']~items=0 then return self~error(outcome,'candidate provenance empty')
  return outcome

::method error class
  use strict arg outcome, message
  outcome['OK']=.false; outcome['ERRORS']~append(message); return outcome

::method knownUnit class
  use strict arg unit
  allowed=.array~of('','1','Pa','MPa','GPa','N','N*m','kg','g','mm','cm','m','nm','mm2','mm3','Ohm','V','A','W','F','uF','nF','H','Hz','K','K/W','deg','rpm')
  do item over allowed
    if unit~string=item then return .true
  end
  return .false

::method dimensionName class
  use strict arg name
  n=name~string~upper
  return n~pos('DIAMETER')>0 | n~pos('WIDTH')>0 | n~pos('HEIGHT')>0 | n~pos('LENGTH')>0 | n~pos('THICKNESS')>0 | n~pos('BORE')>0

::class PartResearchGenerator public

::method render class
  use strict arg candidate
  id=self~safe(candidate['id']); family=self~safe(candidate['family']); description=self~safe(candidate['description'])
  out='/* Generated from validated parts.research/0.1 candidate; review provenance before acceptance. */'||'0d0a'x
  out=out||'::method candidate_'||id~translate('_','-')||' class'||'0d0a'x
  out=out||'  p=.directory~new'||'0d0a'x
  do property over candidate['properties']
    key=self~safe(property['name'])~translate('_','-')
    out=out||'  p['''||key~string~upper||''']='''||self~safe(property['value'])||' '||property['unit']||''' '||'0d0a'x
  end
  out=out||'  m=.directory~new'||'0d0a'x
  do role over candidate['materialRoles']
    out=out||'  m['''||self~safe(role['role'])~string~upper||''']='''||self~safe(role['materialId'])||''' '||'0d0a'x
  end
  out=out||'  return .PartDefinition~new('''||id||''','''||family||''','''||description||''',p,m)'||'0d0a'x
  return out

::method safe class
  use strict arg text
  t=text~string
  if t~pos('::')>0 | t~pos('''')>0 | t~pos('0d0a'x)>0 then return t~changeStr('''','''''')
  return t~changeStr('''','''''')

::class PartResearchBudget public
::attribute ceiling get
::attribute stopAt get
::attribute spent get

::method init
  expose ceiling stopAt spent
  use strict arg ceilingArg=70, stopAtArg=68
  ceiling=ceilingArg; stopAt=stopAtArg; spent=0

::method canSpend
  expose stopAt spent
  use strict arg amount
  return spent+amount<=stopAt

::method charge
  expose ceiling spent
  use strict arg amount
  if spent+amount>ceiling then raise syntax 93.900 array('AI budget exceeded')
  spent+=amount; return spent

::class PartResearchCache public
::attribute entries get

::method init
  expose entries
  entries=.directory~new

::method put
  expose entries
  use strict arg key, requestJSON, responseJSON, disposition
  e=.directory~new; e['key']=key; e['request']=requestJSON; e['response']=responseJSON; e['disposition']=disposition; entries[key]=e; return e

::method get
  expose entries
  use strict arg key
  if \entries~hasIndex(key) then return .nil
  return entries[key]

::method toJSON
  expose entries
  return .JSON~toJSON(entries)

::method write
  expose entries
  use strict arg path
  call lineout path,.JSON~toJSON(entries)
  call lineout path
  return .true

::class PartResearchProperty public
::attribute value get
::method init
  expose value
  use strict arg name, propertyValue, unit, provenance, confidence='UNKNOWN'
  value=.directory~new; value['name']=name; value['value']=propertyValue; value['unit']=unit; value['provenance']=provenance; value['confidence']=confidence
::method toJSON
  expose value
  return .JSON~toJSON(value)

::class PartResearchMaterialRole public
::attribute value get
::method init
  expose value
  use strict arg role, materialId, provenance='existing Materials catalogue'
  value=.directory~new; value['role']=role; value['materialId']=materialId; value['provenance']=provenance

::class PartResearchGeometry public
::attribute value get
::method init
  expose value
  use strict arg geometry=.nil
  if geometry=.nil then geometry=.directory~new
  value=geometry

::class PartResearchProvenance public
::attribute value get
::method init
  expose value
  use strict arg source, kind='ENGINEERING_REFERENCE', note=''
  value=.directory~new; value['source']=source; value['kind']=kind; value['note']=note

::class PartResearchPrompt public
::method forRequest class
  use strict arg request
  return 'Return only JSON matching parts.research.response/0.1. Do not emit ooRexx source. Every numeric property needs value, unit, provenance, confidence. Use UNKNOWN when evidence is insufficient. Existing material IDs are authoritative.'||'0d0a'x||.JSON~toJSON(request)

::class PartResearchFactory public

::method process class
  use strict arg request, responseJSON, existingPartIds=.nil
  if existingPartIds=.nil then existingPartIds=.array~new
  response=.PartResearchResponse~fromJSON(responseJSON)~value
  outcome=.PartResearchValidator~validate(response,request~value,existingPartIds)
  disposition='REJECTED'
  if outcome['OK'] then do
    if response['status']='UNKNOWN' then disposition='ACCEPTED_WITH_UNKNOWNS'
    else disposition='ACCEPTED'
  end
  envelope=.directory~new; envelope['disposition']=disposition; envelope['validation']=outcome; envelope['response']=response
  if outcome['OK'] & response['status']<>'UNKNOWN' then envelope['generatedSource']=.PartResearchGenerator~render(response['candidate'])
  return envelope

::method repairRequest class
  use strict arg request, validationErrors, previousCandidate
  d=.directory~new; d['schema']='parts.research.repair/0.1'; d['originalRequestId']=request~value['requestId']; d['validationErrors']=validationErrors; d['previousCandidate']=previousCandidate; d['instruction']='Correct only the listed validation defects; preserve all other fields and return the response schema.'; return d

::class PartResearchModelPolicy public
::attribute textModel get
::attribute visionModel get
::attribute inputUsdPerMillion get
::attribute outputUsdPerMillion get

::method init
  expose textModel visionModel inputUsdPerMillion outputUsdPerMillion
  use strict arg textModelArg='gpt-4.1-mini', visionModelArg='gpt-4o', inputCostArg=0.40, outputCostArg=1.60
  textModel=textModelArg; visionModel=visionModelArg; inputUsdPerMillion=inputCostArg; outputUsdPerMillion=outputCostArg

::method modelFor
  expose textModel visionModel
  use strict arg task='TEXT_EXTRACTION', hasImages=.false
  if hasImages=.true | task~string~upper='VISION_EXTRACTION' then return visionModel
  return textModel

::method estimateUsd
  expose inputUsdPerMillion outputUsdPerMillion
  use strict arg inputTokens, outputTokens
  return (inputTokens*inputUsdPerMillion/1000000)+(outputTokens*outputUsdPerMillion/1000000)

::method estimateRequests
  use strict arg usdBudget, inputTokens=2000, outputTokens=300
  cost=self~estimateUsd(inputTokens,outputTokens)
  if cost=0 then return 0
  return trunc(usdBudget/cost)

::requires 'json.cls'
