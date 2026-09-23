/* ooRexx SSH foundation v0.1-dev1
 *
 * SSH transport is native (Foreign Runtime + provider such as libssh).
 * Endpoint semantics remain in ooRexx.  A shell is not an implicit endpoint.
 */

::class SshRequestKinds public
::method subsystem class; return 'SUBSYSTEM'
::method exec class; return 'EXEC'
::method shell class; return 'SHELL'

::class SshEndpointRequest public
::method init
  expose _kind _name _channel _session _metadata
  use strict arg kind, name='', channel=.nil, session=.nil, metadata=.nil
  _kind=translate(kind)
  _name=name
  _channel=channel
  _session=session
  if metadata==.nil then _metadata=.directory~new
  else _metadata=metadata
::method kind; expose _kind; return _kind
::method name; expose _name; return _name
::method channel; expose _channel; return _channel
::method session; expose _session; return _session
::method metadata; expose _metadata; return _metadata

::class SshEndpointDecision public
::method init
  expose _allowed _handler _reason _endpointName
  use strict arg allowed, handler=.nil, reason='', endpointName=''
  _allowed=allowed
  _handler=handler
  _reason=reason
  _endpointName=endpointName
::method allowed; expose _allowed; return _allowed
::method handler; expose _handler; return _handler
::method reason; expose _reason; return _reason
::method endpointName; expose _endpointName; return _endpointName

::class SshEndpointRegistry public
::method init
  expose _subsystems _exec _shell
  _subsystems=.directory~new
  _exec=.directory~new
  _shell=.nil

::method registerSubsystem
  expose _subsystems
  use strict arg name, handler
  if name=='' then raise syntax 88.900 array('SSH subsystem name must not be empty')
  _subsystems[name]=handler
  return self

::method registerExec
  expose _exec
  use strict arg verb, handler
  if verb=='' then raise syntax 88.900 array('SSH exec verb must not be empty')
  if pos(' ',verb)>0 | pos('09'x,verb)>0 then raise syntax 88.900 array('SSH exec registration is a single verb, not shell syntax')
  _exec[verb]=handler
  return self

::method registerShell
  expose _shell
  use strict arg handler
  _shell=handler
  return self

::method resolve
  expose _subsystems _exec _shell
  use strict arg request
  kind=request~kind
  if kind='SUBSYSTEM' then do
    handler=_subsystems[request~name]
    if handler==.nil then return .SshEndpointDecision~new(.false,.nil,'UNKNOWN_SUBSYSTEM',request~name)
    return .SshEndpointDecision~new(.true,handler,'',request~name)
  end
  if kind='EXEC' then do
    raw=request~name~strip
    if raw=='' then return .SshEndpointDecision~new(.false,.nil,'EMPTY_EXEC','')
    parse var raw verb rest
    handler=_exec[verb]
    if handler==.nil then return .SshEndpointDecision~new(.false,.nil,'UNKNOWN_EXEC',verb)
    return .SshEndpointDecision~new(.true,handler,'',verb)
  end
  if kind='SHELL' then do
    if _shell==.nil then return .SshEndpointDecision~new(.false,.nil,'SHELL_NOT_INSTALLED','shell')
    return .SshEndpointDecision~new(.true,_shell,'','shell')
  end
  return .SshEndpointDecision~new(.false,.nil,'UNKNOWN_REQUEST_KIND',kind)

::class SshAuthority public
::method allow
  use strict arg identity, request
  return .false

::class SshAllowAllAuthority subclass SshAuthority public
::method allow
  use strict arg identity, request
  return .true

::class SshEndpointAuthority subclass SshAuthority public
::method init
  expose _rules
  _rules=.directory~new
::method allowEndpoint
  expose _rules
  use strict arg identity, kind, endpoint
  key=identity||'|'||translate(kind)||'|'||endpoint
  _rules[key]=.true
  return self
::method allow
  expose _rules
  use strict arg identity, request
  endpoint=request~name
  if request~kind='EXEC' then do
    raw=endpoint~strip
    parse var raw endpoint .
  end
  key=identity||'|'||request~kind||'|'||endpoint
  return _rules[key]==.true

::class SshServer public
::method init
  expose _provider _registry _authority
  use strict arg provider, registry=.nil, authority=.nil
  _provider=provider
  if registry==.nil then _registry=.SshEndpointRegistry~new
  else _registry=registry
  if authority==.nil then _authority=.SshAuthority~new
  else _authority=authority
::method provider; expose _provider; return _provider
::method registry; expose _registry; return _registry
::method authority; expose _authority; return _authority
::method resolve
  expose _registry _authority
  use strict arg identity, request
  if \_authority~allow(identity,request) then return .SshEndpointDecision~new(.false,.nil,'AUTHORITY_DENIED',request~name)
  return _registry~resolve(request)

::class SshForeignLibsshProvider public
::method init
  expose _lib _bridgePath _minimumServerVersion
  use strict arg bridgePath, minimumServerVersion='0.11.5'
  _bridgePath=bridgePath
  _minimumServerVersion=minimumServerVersion
  _lib=.foreign~load(bridgePath)

::method nativeLibrary
  expose _lib
  return _lib
::method providerPath
  expose _lib
  return _lib~providerPath
::method version
  expose _lib
  return _lib~version(0)
::method minimumServerVersion
  expose _minimumServerVersion
  return _minimumServerVersion
::method versionNumber private
  use strict arg text
  numeric digits 20
  parse var text plain '/' .
  parse var plain major '.' minor '.' patch
  if major=='' then major=0
  if minor=='' then minor=0
  if patch=='' then patch=0
  /* tolerate suffixes after numeric patch */
  clean=''
  do i=1 to length(patch)
    c=substr(patch,i,1)
    if c<'0' | c>'9' then leave
    clean=clean||c
  end
  if clean=='' then clean=0
  return (major+0)*1000000 + (minor+0)*1000 + (clean+0)
::method serverVersionAllowed
  expose _minimumServerVersion
  use strict arg versionText=(self~version)
  return self~versionNumber(versionText) >= self~versionNumber(_minimumServerVersion)
::method clientCapable
  return .true
::method serverCapable
  return self~serverVersionAllowed
::method session
  expose _lib
  return _lib~session_new
::method bind
  expose _lib
  if \self~serverCapable then raise syntax 88.900 array('Native libssh is below the configured server minimum',self~version,self~minimumServerVersion)
  return _lib~bind_new
::method probe
  expose _lib
  d=.directory~new
  d['provider']=_lib~provider
  d['provider_path']=_lib~providerPath
  d['version']=self~version
  d['client_capable']=self~clientCapable
  d['server_capable']=self~serverCapable
  d['minimum_server_version']=self~minimumServerVersion
  return d

::requires 'foreign.cls'
