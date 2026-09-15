/* Declarative predicate over authoritative facts/decisions; never browser script. */
::class WireUIConditionDesign subclass AlchemyObject public
::attribute conditionId get
::attribute version get
::attribute sourceKind get
::attribute sourceRef get
::attribute operator get
::attribute authorityRef get
::attribute contentAddress get
::method init
  expose conditionId version sourceKind sourceRef operator expectedValue authorityRef metadata contentAddress
  use arg conditionId, version, sourceKind, sourceRef, operator, expectedValue=.nil, authorityRef="", metadata=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned authoritative presentation condition"))
  conditionId=conditionId~string~strip; version=version~string~strip; sourceKind=sourceKind~string~strip~translate
  sourceRef=sourceRef~string~strip; operator=operator~string~strip~translate; authorityRef=authorityRef~string~strip
  if conditionId="" | version="" | sourceRef="" | authorityRef="" then raise syntax 93.906 array("condition",conditionId)
  if \(.set~of("FACT","DECISION")~hasIndex(sourceKind)) then raise syntax 93.914 array("sourceKind",sourceKind)
  if \(.set~of("EQ","NE","PRESENT","ABSENT","TRUE","FALSE")~hasIndex(operator)) then raise syntax 93.914 array("operator",operator)
  if (operator="EQ" | operator="NE") & expectedValue==.nil then raise syntax 93.906 array("condition expectedValue",conditionId)
  metadata=.WireUIDesignUtil~copyTable(metadata); contentAddress=.WireUIDesignUtil~token(self~canonicalText)
::method expectedValue
  expose expectedValue; return expectedValue
::method canonicalText
  expose conditionId version sourceKind sourceRef operator expectedValue authorityRef metadata
  return conditionId"|"version"|"sourceKind"|"sourceRef"|"operator"|"authorityRef"|".WireUIDesignUtil~canonicalValue(expectedValue)"|".WireUIDesignUtil~canonicalTable(metadata)
::method ref
  expose conditionId version contentAddress
  return .WireUIArtifactRef~new("CONDITION",conditionId,version,contentAddress)
::method asWire
  expose conditionId version sourceKind sourceRef operator expectedValue authorityRef metadata contentAddress
  d=.table~new; d["conditionId"]=conditionId; d["version"]=version; d["sourceKind"]=sourceKind; d["sourceRef"]=sourceRef; d["operator"]=operator; d["expectedValue"]=expectedValue; d["authorityRef"]=authorityRef; d["metadata"]=.WireUIDesignUtil~copyTable(metadata); d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
