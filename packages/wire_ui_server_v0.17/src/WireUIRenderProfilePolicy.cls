/* Server-authoritative renderer capability profile selection.
   Interaction profile (HUMAN_VISUAL/AI_AGENT_OPTIMISED) is deliberately separate. */
::class WireUIRenderProfilePolicy subclass AlchemyObject public
::attribute defaultProfileId get

::method init
  expose defaultProfileId fingerprintProfiles
  use arg defaultProfileId="generic"
  self~init:super(.WireUIAlchemy~metadata("Server-authoritative Wire UI renderer capability profile policy"))
  defaultProfileId=defaultProfileId~string~strip
  if defaultProfileId="" then defaultProfileId="generic"
  fingerprintProfiles=.table~new
  self~registerStateVariable("defaultProfileId","PUBLIC","fallback renderer capability profile")

::method registerFingerprint
  expose fingerprintProfiles
  use arg fingerprint, profileId
  fingerprint=fingerprint~string~strip
  profileId=profileId~string~strip
  if fingerprint="" | profileId="" then return .WireUIResult~failure("RENDER_PROFILE_MAPPING_INVALID")
  fingerprintProfiles[fingerprint]=profileId
  return .WireUIResult~success(profileId,"RENDER_PROFILE_MAPPING_REGISTERED")

::method resolve
  expose fingerprintProfiles defaultProfileId
  use arg capabilities=.nil, fingerprint=""
  fingerprint=fingerprint~string~strip
  if fingerprint<>"" & fingerprintProfiles~hasIndex(fingerprint) then return fingerprintProfiles[fingerprint]

  /* Deterministic conservative derivation for known coarse capability classes.
     This does not let the browser choose arbitrary code; it only selects a named
     server renderer profile from already-declared coarse capability facts. */
  if capabilities\==.nil & capabilities~hasMethod("HASINDEX") then do
    viewport=self~field(capabilities,"viewportClass","")
    pointer=self~field(capabilities,"pointer","")
    if viewport<>"" & pointer<>"" then return viewport"-"pointer
  end
  return defaultProfileId

::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default

::requires "WireUIProtocol.cls"
::requires "WireUIAlchemy.cls"
