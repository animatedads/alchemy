/* MasHostIdentity.cls - trusted host attribution seam for production bindings.
 * Guest fields are never identity/authority evidence.  A resolver is injected by
 * the host environment after its own authenticated MVS/session boundary.
 */
::class MasHostIdentity public
::method init public
  expose principalId source evidence
  use strict arg principalIdArg, sourceArg='HOST', evidenceArg=''
  principalId=principalIdArg~string~strip
  source=sourceArg~string~strip
  evidence=evidenceArg~string
  if principalId='' then raise syntax 88.900 array('MAS_PRINCIPAL_REQUIRED')
::attribute principalId get
::attribute source get
::attribute evidence get

::class MasHostIdentityResolver public
::method resolve abstract

/* Qualification-only resolver.  Production deployments must inject their
 * authenticated identity boundary rather than deriving principal from guest data.
 */
::class MasFixedHostIdentityResolver subclass MasHostIdentityResolver public
::method init public
  expose identity
  use strict arg principalId, source='QUALIFICATION_FIXED', evidence=''
  identity=.MasHostIdentity~new(principalId,source,evidence)
::method resolve public
  expose identity
  use strict arg sessionId, context=.nil
  return identity
