/*
 * CivicPort v0.9 transport-only credential seam.
 *
 * Credential references are non-secret evidence and may be retained in
 * CivicRequest/CivicDocument. Secret material is resolved only inside the
 * transport boundary and is never added to CivicRequest headers.
 */

::class CivicCredentialMaterializationResult subclass CivicAlchemyObject public
::attribute ok get
::attribute credentialRef get
::attribute scheme get
::attribute errorCode get
::attribute message get

::method success class
  use arg credentialRef, scheme
  return .CivicCredentialMaterializationResult~new(.true, credentialRef, scheme, "", "")

::method failure class
  use arg credentialRef, code, message
  return .CivicCredentialMaterializationResult~new(.false, credentialRef, "", code, message)

::method init
  expose ok credentialRef scheme errorCode message
  use arg okArg, refArg, schemeArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  credentialRef = refArg~string
  scheme = schemeArg~string
  errorCode = codeArg~string
  message = messageArg~string


::class CivicCredentialBinding subclass CivicAlchemyObject public
::attribute credentialRef get
::attribute environmentVariable get
::attribute host get
::attribute scheme get

::method init
  expose credentialRef environmentVariable host scheme
  use arg refArg, envArg, hostArg, schemeArg = "BASIC_API_KEY"
  ignore = self~initCivicAlchemy
  credentialRef = refArg~string
  environmentVariable = envArg~string
  host = hostArg~string~lower
  scheme = schemeArg~string~translate
  if credentialRef = "" then raise syntax 93.900 additional("Civic credential binding requires a non-secret reference")
  if environmentVariable = "" then raise syntax 93.900 additional("Civic credential binding requires an environment variable name")
  if host = "" then raise syntax 93.900 additional("Civic credential binding requires an exact host")
  if scheme \= "BASIC_API_KEY" then raise syntax 93.900 additional("Unsupported Civic credential scheme: " || scheme)

::method identity
  expose credentialRef environmentVariable host scheme
  return "CIVICCRED-BINDING-V1:" || credentialRef || ":" || scheme || ":ENV:" || environmentVariable || ":HOST:" || host


::class CivicEnvironmentCredentialProvider subclass CivicAlchemyObject public
::attribute sealed get

::method init
  expose bindings sealed
  ignore = self~initCivicAlchemy
  bindings = .directory~new
  sealed = .false

::method addBasicApiKey
  expose bindings sealed
  use arg credentialRef, environmentVariable, host
  if sealed then raise syntax 93.900 additional("Civic credential provider is sealed")
  ref = credentialRef~string
  if \self~safeReference(ref) then raise syntax 93.900 additional("Civic credential reference contains unsupported characters")
  envName = environmentVariable~string
  if \self~safeEnvironmentName(envName) then raise syntax 93.900 additional("Civic credential environment variable name is invalid")
  binding = .CivicCredentialBinding~new(ref, envName, host, "BASIC_API_KEY")
  if bindings~hasIndex(ref) then raise syntax 93.900 additional("Civic credential reference already exists: " || ref)
  bindings[ref] = binding
  return binding

::method seal
  expose sealed
  sealed = .true
  return self

::method sealedCopy
  expose bindings
  copied = .CivicEnvironmentCredentialProvider~new
  do ref over bindings~allIndexes
    binding = bindings[ref]
    ignore = copied~addBasicApiKey(binding~credentialRef, binding~environmentVariable, binding~host)
  end
  return copied~seal

::method binding
  expose bindings
  use arg credentialRef
  return bindings[credentialRef~string]

::method describe
  expose bindings
  descriptions = .array~new
  refs = bindings~allIndexes
  refs~sort
  do ref over refs
    binding = bindings[ref]
    descriptions~append(binding~identity)
  end
  return descriptions

::method materializeCurlConfig
  expose bindings
  use arg request, configPath
  if request == .nil then return .CivicCredentialMaterializationResult~failure("", "CREDENTIAL_REQUEST_MISSING", "CivicRequest is required")
  ref = request~credentialRef
  if ref = "" then return .CivicCredentialMaterializationResult~failure("", "CREDENTIAL_REFERENCE_MISSING", "CivicRequest has no credential reference")
  binding = bindings[ref]
  if binding == .nil then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_REFERENCE_UNKNOWN", "No credential binding exists for reference " || ref)

  parts = .CivicUrlParts~parse(request~url)
  if parts == .nil then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_URL_INVALID", "CivicRequest URL is invalid")
  if parts~host \== binding~host then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_HOST_MISMATCH", "Credential reference is not authorized for host " || parts~host)

  secret = value(binding~environmentVariable, , "ENVIRONMENT")
  if secret = "" then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_SECRET_UNAVAILABLE", "Credential environment variable is absent or empty: " || binding~environmentVariable)
  if secret~pos('0d'x) > 0 | secret~pos('0a'x) > 0 | secret~pos('00'x) > 0 then -
    return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_SECRET_INVALID", "Credential secret contains CR, LF, or NUL")

  path = configPath~string
  if path = "" then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_CONFIG_PATH_MISSING", "Transport credential config path is required")
  streamObject = .Stream~new(path)
  opened = streamObject~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_CONFIG_OPEN_FAILED", "Cannot create transport credential config")
  ignore = streamObject~close
  address system "chmod 600 " || self~shellQuote(path)
  chmodRc = rc
  if chmodRc \= 0 then do
    ignore = SysFileDelete(path)
    return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_CONFIG_MODE_FAILED", "Cannot restrict transport credential config")
  end

  streamObject = .Stream~new(path)
  opened = streamObject~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then do
    ignore = SysFileDelete(path)
    return .CivicCredentialMaterializationResult~failure(ref, "CREDENTIAL_CONFIG_OPEN_FAILED", "Cannot reopen transport credential config")
  end
  configLine = 'user = "' || self~curlConfigEscape(secret || ":") || '"' || '0a'x
  ignore = streamObject~charOut(configLine)
  ignore = streamObject~close
  secret = ""
  return .CivicCredentialMaterializationResult~success(ref, binding~scheme)

::method safeReference private
  use arg text
  if text = "" | text~length > 128 then return .false
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if \datatype(ch, "A") & \datatype(ch, "N") & ch \= "." & ch \= "_" & ch \= "-" & ch \= ":" then return .false
  end
  return .true

::method safeEnvironmentName private
  use arg text
  if text = "" | text~length > 128 then return .false
  first = text~substr(1, 1)
  if \datatype(first, "A") & first \= "_" then return .false
  do i = 2 to text~length
    ch = text~substr(i, 1)
    if \datatype(ch, "A") & \datatype(ch, "N") & ch \= "_" then return .false
  end
  return .true

::method shellQuote private
  use arg value
  text = value~string~changestr("'", "'\\''")
  return "'" || text || "'"

::method curlConfigEscape private
  use arg text
  escaped = text~changestr("\\", "\\\\")
  escaped = escaped~changestr('"', '\\"')
  return escaped

::requires "CivicPolicy.cls"
::requires "CivicAlchemy.cls"
