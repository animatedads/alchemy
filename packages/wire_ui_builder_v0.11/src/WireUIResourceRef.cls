/*
  Exact reference to a resource authored outside Wire UI Builder.

  The Builder never owns resource bytes and never offers arbitrary display-copy
  authoring. A Resource Editor (or another resource authority) publishes the
  resource; Builder projections only bind this immutable identity.
*/
::class WireUIResourceRef public
::attribute resourceId get
::attribute version get
::attribute contentAddress get
::attribute resourceClass get
::attribute locale get
::method init
  expose resourceId version contentAddress resourceClass locale
  use arg resourceId, version, contentAddress, resourceClass="STRUCTURED", locale=""
  resourceId=resourceId~string~strip; version=version~string~strip; contentAddress=contentAddress~string~strip
  resourceClass=resourceClass~string~strip~translate; locale=locale~string~strip
  if resourceId="" | version="" | contentAddress="" then raise syntax 93.906 array("fixed resource reference",resourceId)
  if \(.set~of("TEXT","GRAPHIC","AUDIO","VIDEO","STRUCTURED","COMPOUND","OTHER")~hasIndex(resourceClass)) then raise syntax 93.914 array("resourceClass",resourceClass)
::method canonicalText
  expose resourceId version contentAddress resourceClass locale
  return resourceId"|"version"|"contentAddress"|"resourceClass"|"locale
::method asWire
  expose resourceId version contentAddress resourceClass locale
  d=.table~new; d["resourceId"]=resourceId; d["version"]=version; d["contentAddress"]=contentAddress; d["resourceClass"]=resourceClass; d["locale"]=locale; return d
::method fromWire class
  use arg row
  if row==.nil | \(row~isA(.Table) | row~isA(.Directory)) then raise syntax 93.948 array("resourceRef")
  id=""; if row~hasIndex("resourceId") then id=row["resourceId"]; else if row~hasIndex("id") then id=row["id"]
  v=""; if row~hasIndex("version") then v=row["version"]
  ca=""; if row~hasIndex("contentAddress") then ca=row["contentAddress"]
  rc="STRUCTURED"; if row~hasIndex("resourceClass") then rc=row["resourceClass"]
  locale=""; if row~hasIndex("locale") then locale=row["locale"]
  return self~new(id,v,ca,rc,locale)
::requires "WireUIDesignSupport.cls"
