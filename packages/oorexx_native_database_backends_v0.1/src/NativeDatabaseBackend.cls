/* NativeDatabaseBackend.cls - provider-neutral database backend contracts v0.1 */

::class NativeDatabaseCapabilityStatus public
::constant SUPPORTED   "SUPPORTED"
::constant UNSUPPORTED "UNSUPPORTED"
::constant CONDITIONAL "CONDITIONAL"
::constant UNKNOWN     "UNKNOWN"

::class NativeDatabaseQualification public
::constant TESTED              "TESTED"
::constant DECLARED            "DECLARED"
::constant UNTESTED            "UNTESTED"
::constant ENVIRONMENT_SKIPPED "ENVIRONMENT_SKIPPED"

::class NativeDatabaseImplementationKind public
::constant OOREXX_NATIVE   "OOREXX_NATIVE"
::constant FOREIGN_RUNTIME "FOREIGN_RUNTIME"
::constant PROCESS_BRIDGE  "PROCESS_BRIDGE"

::class NativeDatabaseCapability public
::method init
  expose name status qualification detail evidence
  use strict arg name, status, qualification = "DECLARED", detail = "", evidence = ""
  name = name~string~upper
  status = status~string~upper
  qualification = qualification~string~upper
  detail = detail~string
  evidence = evidence~string
::attribute name get
::attribute status get
::attribute qualification get
::attribute detail get
::attribute evidence get
::method supported
  expose status
  return status = .NativeDatabaseCapabilityStatus~SUPPORTED
::method asDirectory
  expose name status qualification detail evidence
  d=.directory~new
  d["name"]=name; d["status"]=status; d["qualification"]=qualification
  d["detail"]=detail; d["evidence"]=evidence
  return d

::class NativeDatabaseCapabilitySet public
::method init
  expose values
  values=.directory~new
::method put
  expose values
  use strict arg capability
  values[capability~name]=capability
  return self
::method get
  expose values
  use strict arg name
  return values[name~string~upper]
::method status
  c=self~get(arg(1))
  if c==.nil then return .NativeDatabaseCapabilityStatus~UNKNOWN
  return c~status
::method supports
  c=self~get(arg(1))
  if c==.nil then return .false
  return c~supported
::method all
  expose values
  a=.array~new
  keys=values~allIndexes; keys~sort
  do k over keys; a~append(values[k]); end
  return a
::method snapshot
  d=.directory~new
  do c over self~all; d[c~name]=c~asDirectory; end
  return d

::class NativeDatabaseLimitation public
::method init
  expose code scope detail severity
  use strict arg code, detail, scope="IMPLEMENTATION", severity="DOCUMENTED"
  code=code~string~upper; detail=detail~string; scope=scope~string~upper; severity=severity~string~upper
::attribute code get
::attribute scope get
::attribute detail get
::attribute severity get
::method asDirectory
  expose code scope detail severity
  d=.directory~new; d["code"]=code; d["scope"]=scope; d["detail"]=detail; d["severity"]=severity
  return d

::class NativeDatabaseRequirement public
::method init
  expose name required detail
  use strict arg name, required=.true, detail=""
  name=name~string~upper; required=required; detail=detail~string
::attribute name get
::attribute required get
::attribute detail get

::class NativeDatabaseBackend public
::method init
  expose family implementation version implementationKind priority capabilities limitations requirements
  use strict arg family, implementation, version, implementationKind, priority=100
  family=family~string~upper
  implementation=implementation~string
  version=version~string
  implementationKind=implementationKind~string~upper
  priority=priority
  capabilities=.NativeDatabaseCapabilitySet~new
  limitations=.array~new
  requirements=.array~new
::attribute family get
::attribute implementation get
::attribute version get
::attribute implementationKind get
::attribute priority get
::attribute capabilities get
::attribute limitations get
::attribute requirements get
::method implementationId
  expose family implementation version
  return family || ":" || implementation || ":" || version
::method addCapability
  expose capabilities
  use strict arg name, status, qualification="DECLARED", detail="", evidence=""
  capabilities~put(.NativeDatabaseCapability~new(name,status,qualification,detail,evidence))
  return self
::method addLimitation
  expose limitations
  use strict arg code, detail, scope="IMPLEMENTATION", severity="DOCUMENTED"
  limitations~append(.NativeDatabaseLimitation~new(code,detail,scope,severity))
  return self
::method addRequirement
  expose requirements
  use strict arg name, required=.true, detail=""
  requirements~append(.NativeDatabaseRequirement~new(name,required,detail))
  return self
::method supports
  expose capabilities
  return capabilities~supports(arg(1))
::method available
  return .true
::method availabilityEvidence
  d=.directory~new; d["available"]=self~available; d["implementation_id"]=self~implementationId
  return d
::method acquire
  raise syntax 93.900 array("Backend does not implement acquire():" self~implementationId)
::method publicDescription
  expose family implementation version implementationKind priority capabilities limitations requirements
  d=.directory~new
  d["family"]=family; d["implementation"]=implementation; d["version"]=version
  d["implementation_kind"]=implementationKind; d["priority"]=priority
  d["capabilities"]=capabilities~snapshot
  la=.array~new; do l over limitations; la~append(l~asDirectory); end; d["limitations"]=la
  ra=.array~new
  do r over requirements
    q=.directory~new; q["name"]=r~name; q["required"]=r~required; q["detail"]=r~detail; ra~append(q)
  end
  d["requirements"]=ra
  return d

::class NativeDatabaseBackendLease public
::method init
  expose backend session pinned
  use strict arg backend, session
  pinned=.true
::attribute backend get
::attribute session get
::attribute pinned get
::method implementationId
  expose backend
  return backend~implementationId
::method close
  expose session pinned
  if pinned then do
    if session\==.nil then if session~hasMethod("CLOSE") then session~close
    pinned=.false
  end
::method uninit
  expose session pinned
  if symbol("PINNED")="VAR" then if pinned then if session\==.nil then if session~hasMethod("CLOSE") then session~close

::class NativeDatabaseBackendSelector public
::method select
  use strict arg backends, requiredCapabilities=.nil, family=""
  if requiredCapabilities==.nil then requiredCapabilities=.array~new
  chosen=.nil
  do backend over backends
    if family<>"" then if backend~family<>family~upper then iterate
    if \backend~available then iterate
    eligible=.true
    do capability over requiredCapabilities
      if \backend~supports(capability) then do; eligible=.false; leave; end
    end
    if \eligible then iterate
    if chosen==.nil then chosen=backend
    else if backend~priority<chosen~priority then chosen=backend
  end
  return chosen
::method acquire
  use strict arg backends, connection, requiredCapabilities=.nil, family=""
  backend=self~select(backends,requiredCapabilities,family)
  if backend==.nil then return .nil
  session=backend~acquire(connection)
  if session==.nil then return .nil
  return .NativeDatabaseBackendLease~new(backend,session)
