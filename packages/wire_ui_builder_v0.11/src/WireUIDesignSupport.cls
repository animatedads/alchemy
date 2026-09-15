/* Shared support for versioned Wire UI authoring artifacts. */
::requires "AlchemyObject.cls"
::requires "crypto.cls"

::class WireUIDesignAlchemy public
::constant PACKAGE_VERSION "0.11"
::constant SCHEMA "WIRE-UI-DESIGN/0.7"
::method metadata class
  use arg purpose, limitations = .nil
  m=.directory~new
  m["purpose"]=purpose
  m["package"]="wire_ui_builder"
  m["package_version"]=self~PACKAGE_VERSION
  m["authorship"]=.array~of("Alchemy Wire UI")
  m["standards"]=.array~of("ALCHEMY-HOUSE-OBJECT-0.5", self~SCHEMA, "WIRE-UI/0.1")
  if limitations == .nil then limitations=.array~of("authoring/compiler schema v0.7; Builder product v0.11; first-class journey flows, declarative conditional placements and transitions, preview-only condition simulation, presentation arbitration, and fixed external resource bindings; compiled interaction package contract remains WIRE-UI/0.1")
  m["design_limitations"]=limitations
  return m

::class WireUIDesignResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::method init
  expose ok code value detail
  use arg ok, code="OK", value=.nil, detail=""
::method success class
  use arg value=.nil, code="OK"
  return self~new(.true,code,value,"")
::method failure class
  use arg code, detail="", value=.nil
  return self~new(.false,code,value,detail)

::class WireUIDesignUtil public
::method token class
  use arg text
  numeric digits 20
  h=2166136261
  text=text~string
  do i=1 to text~length
    h=(h*16777619 + text~substr(i,1)~c2d) // 2147483647
  end
  return "wuid01-" || d2x(h~format(,0),8)

::method hashNumber class
  use arg text
  numeric digits 20
  h=2166136261
  text=text~string
  do i=1 to text~length
    h=(h*16777619 + text~substr(i,1)~c2d) // 2147483647
  end
  return h

::method strongToken class
  use arg text
  return "sha512-" || .SHA512~new(text~string)~digest

::method copyTable class
  use arg source
  target=.table~new
  if source == .nil then return target
  do k over source~allIndexes
    target[k]=source[k]
  end
  return target

::method copyArray class
  use arg source
  target=.array~new
  if source == .nil then return target
  do v over source; target~append(v); end
  return target

::method canonicalTable class
  use arg source
  if source == .nil then return "{}"
  keys=source~allIndexes
  keys~sort
  text="{"
  first=.true
  do k over keys
    if \first then text ||= ","
    first=.false
    text ||= self~escape(k) || ":" || self~canonicalValue(source[k])
  end
  return text || "}"

::method canonicalArray class
  use arg source
  if source == .nil then return "[]"
  text="["
  first=.true
  do v over source
    if \first then text ||= ","
    first=.false
    text ||= self~canonicalValue(v)
  end
  return text || "]"

::method canonicalValue class
  use arg value
  if value == .nil then return "null"
  if value~isA(.Table) | value~isA(.Directory) then return self~canonicalTable(value)
  if value~isA(.Array) then return self~canonicalArray(value)
  if value~isA(.Set) then do
    a=value~makeArray; a~sort; return self~canonicalArray(a)
  end
  if value~hasMethod("CANONICALTEXT") then return "<" || value~canonicalText || ">"
  return self~escape(value~string)

::method escape class private
  use arg s
  s=s~string
  s=s~changeStr("\\","\\\\")
  s=s~changeStr("|","\\p")
  s=s~changeStr(":","\\c")
  s=s~changeStr(",","\\m")
  return s

::class WireUIArtifactRef subclass AlchemyObject public
::attribute kind get
::attribute artifactId get
::attribute version get
::attribute contentAddress get
::method init
  expose kind artifactId version contentAddress
  use arg kind, artifactId, version, contentAddress=""
  self~init:super(.WireUIDesignAlchemy~metadata("Exact immutable Wire UI artifact reference"))
  kind=kind~string~strip~translate
  artifactId=artifactId~string~strip
  version=version~string~strip
  contentAddress=contentAddress~string~strip
  if kind="" | artifactId="" | version="" then raise syntax 93.906 array("artifact reference", artifactId)
  self~registerStateVariable("artifactId","PUBLIC","stable semantic artifact identity")
  self~registerStateVariable("version","PUBLIC","exact immutable artifact version")
  self~registerStateVariable("contentAddress","PUBLIC","optional exact content address")
::method key
  expose kind artifactId version
  return kind || ":" || artifactId || "@" || version
::method canonicalText
  expose kind artifactId version contentAddress
  return kind || "|" || artifactId || "|" || version || "|" || contentAddress
::method withContentAddress
  expose kind artifactId version
  use arg address
  return .WireUIArtifactRef~new(kind,artifactId,version,address)
::method asWire
  expose kind artifactId version contentAddress
  d=.table~new; d["kind"]=kind; d["id"]=artifactId; d["version"]=version; d["contentAddress"]=contentAddress
  return d
