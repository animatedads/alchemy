/* Exact immutable binding between a running Wire UI application and one compiled site release. */
::class WireUISiteReleaseBinding subclass AlchemyObject public
::attribute releaseId get
::attribute version get
::attribute contentAddress get
::attribute packageContentAddress get
::method init
  expose releaseId version contentAddress packageContentAddress
  use arg releaseId, version, contentAddress, packageContentAddress
  self~init:super(.WireUIAlchemy~metadata("Exact compiled Wire UI site release binding"))
  releaseId=releaseId~string~strip; version=version~string~strip
  contentAddress=contentAddress~string~strip; packageContentAddress=packageContentAddress~string~strip
  if releaseId="" | version="" | contentAddress="" | packageContentAddress="" then raise syntax 93.906 array("site release binding",releaseId)
  self~registerStateVariable("releaseId","PUBLIC","immutable site release identity")
  self~registerStateVariable("version","PUBLIC","exact site release version")
  self~registerStateVariable("contentAddress","PUBLIC","sealed site release content address")
  self~registerStateVariable("packageContentAddress","PUBLIC","compiled interaction package content address")
::method exactKey
  expose releaseId version
  return releaseId"@"version
::method asWire
  expose releaseId version contentAddress packageContentAddress
  d=.table~new; d["releaseId"]=releaseId; d["version"]=version; d["contentAddress"]=contentAddress; d["packageContentAddress"]=packageContentAddress
  return d
::requires "WireUIAlchemy.cls"
