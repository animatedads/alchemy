/*
  Versioned semantic composition for one journey state and interaction profile.
  Conditional participation is declarative: placements reference named
  CONDITION artifacts; no browser script or inline business expression exists.
*/
::class WireUICompositionDesign subclass AlchemyObject public
::attribute compositionId get
::attribute version get
::attribute journeyRef get
::attribute profile get
::attribute stateId get
::attribute layoutModel get
::attribute presentationPolicyRef get
::attribute contentAddress get
::method init
  expose compositionId version journeyRef profile stateId layoutModel placements metadata presentationPolicyRef contentAddress
  use arg compositionId, version, journeyRef, profile, stateId, layoutModel="GRID12", placementRows=.nil, metadata=.nil, presentationPolicyRef=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned semantic layout composition"))
  compositionId=compositionId~string~strip; version=version~string~strip
  profile=profile~string~strip~translate; stateId=stateId~string~strip; layoutModel=layoutModel~string~strip~translate
  if compositionId="" | version="" | profile="" | stateId="" then raise syntax 93.906 array("composition",compositionId)
  if \journeyRef~isA(.WireUIArtifactRef) | journeyRef~kind<>"JOURNEY" then raise syntax 93.948 array("composition journeyRef")
  if presentationPolicyRef<>.nil then if \presentationPolicyRef~isA(.WireUIArtifactRef) | presentationPolicyRef~kind<>"PRESENTATION_POLICY" then raise syntax 93.948 array("presentationPolicyRef")
  if layoutModel<>"GRID12" & layoutModel<>"FLOW" then raise syntax 93.914 array("layoutModel",layoutModel)
  placements=.array~new; if placementRows<>.nil then do row over placementRows; placements~append(self~normalisePlacement(row)); end
  if placements~items=0 then raise syntax 93.906 array("composition placements",compositionId)
  metadata=.WireUIDesignUtil~copyTable(metadata); contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("compositionId","PUBLIC","stable semantic composition identity")
  self~registerStateVariable("version","PUBLIC","immutable semantic composition version")
  self~registerStateVariable("profile","PUBLIC","interaction profile composed")
  self~registerStateVariable("stateId","PUBLIC","journey state composed")
::method normalisePlacement private
  use arg source
  if source==.nil | \(source~isA(.Table) | source~isA(.Directory)) then raise syntax 93.948 array("composition placement")
  d=.table~new; elementId=self~field(source,"elementId","")~string~strip
  if elementId="" then raise syntax 93.906 array("placement elementId")
  d["elementId"]=elementId; d["projectionId"]=self~field(source,"projectionId","")~string~strip
  d["viewportClass"]=self~field(source,"viewportClass","DEFAULT")~string~strip~translate; if d["viewportClass"]="" then d["viewportClass"]="DEFAULT"
  if \(.set~of("DEFAULT","SMALL","MEDIUM","LARGE")~hasIndex(d["viewportClass"])) then raise syntax 93.914 array("viewportClass",d["viewportClass"])
  d["region"]=self~field(source,"region","main")~string~strip; if d["region"]="" then d["region"]="main"
  d["order"]=self~whole(self~field(source,"order",0),0,"order"); d["span"]=self~whole(self~field(source,"span",12),1,"span"); if d["span"]>12 then raise syntax 93.914 array("span",d["span"])
  d["rowSpan"]=self~whole(self~field(source,"rowSpan",1),1,"rowSpan"); d["align"]=self~field(source,"align","STRETCH")~string~strip~translate
  if \(.set~of("START","CENTER","END","STRETCH")~hasIndex(d["align"])) then raise syntax 93.914 array("align",d["align"])
  d["whenMode"]=self~field(source,"whenMode","ALL")~string~strip~translate; if \(.set~of("ALL","ANY")~hasIndex(d["whenMode"])) then raise syntax 93.914 array("whenMode",d["whenMode"])
  d["whenConditionIds"]=self~strings(self~field(source,"whenConditionIds",.nil)); d["suppressConditionIds"]=self~strings(self~field(source,"suppressConditionIds",.nil))
  d["presentationClass"]=self~field(source,"presentationClass","STANDARD")~string~strip~translate; if d["presentationClass"]="" then d["presentationClass"]="STANDARD"
  return d
::method strings private
  use arg source
  a=.array~new; if source==.nil then return a
  if \source~isA(.Array) then raise syntax 93.948 array("condition id array")
  do v over source; s=v~string~strip; if s<>"" then a~append(s); end
  return a
::method whole private
  use arg value, minimum, label; n=value+0; if n<>n~trunc | n<minimum then raise syntax 93.914 array(label,value); return n
::method field private
  use arg t,k,default=.nil; if t<>.nil & t~hasIndex(k) then return t[k]; return default
::method placements
  expose placements; a=.array~new; do row over placements; a~append(.WireUIDesignUtil~copyTable(row)); end; return a
::method placementsFor
  expose placements; use arg elementId, projectionId=""; out=.array~new
  do row over placements; if row["elementId"]<>elementId then iterate; if projectionId<>"" & row["projectionId"]<>"" & row["projectionId"]<>projectionId then iterate; out~append(.WireUIDesignUtil~copyTable(row)); end
  return out
::method canonicalText
  expose compositionId version journeyRef profile stateId layoutModel placements metadata presentationPolicyRef
  pref=""; if presentationPolicyRef<>.nil then pref=presentationPolicyRef~canonicalText
  return compositionId"|"version"|"journeyRef~canonicalText"|"profile"|"stateId"|"layoutModel"|"pref"|".WireUIDesignUtil~canonicalArray(placements)"|".WireUIDesignUtil~canonicalTable(metadata)
::method ref
  expose compositionId version contentAddress; return .WireUIArtifactRef~new("COMPOSITION",compositionId,version,contentAddress)
::method asWire
  expose compositionId version journeyRef profile stateId layoutModel placements metadata presentationPolicyRef contentAddress
  d=.table~new; d["compositionId"]=compositionId; d["version"]=version; d["journeyRef"]=journeyRef~asWire; d["profile"]=profile; d["stateId"]=stateId; d["layoutModel"]=layoutModel
  pp=.array~new; do row over placements; pp~append(.WireUIDesignUtil~copyTable(row)); end; d["placements"]=pp
  if presentationPolicyRef==.nil then d["presentationPolicyRef"]=.nil; else d["presentationPolicyRef"]=presentationPolicyRef~asWire
  d["metadata"]=.WireUIDesignUtil~copyTable(metadata); d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
