/* LdapOpenSslCommon.cls
 * Shared Foreign Runtime/OpenSSL call serialization helpers for LDAP TLS
 * client and server providers.  No identity or LDAP policy is owned here.
 */

::class LdapTlsNativeLane
::method init
  expose owner
  use strict arg owner
::method invoke
  expose owner
  use strict arg library,name,args
  owner~entered
  signal on syntax name failed
  value=library~invokeArray(name,args)
  owner~left
  return value
failed:
  owner~left
  raise propagate
::method sslStep
  expose owner
  use strict arg library,name,args,ssl
  owner~entered
  signal on syntax name failed
  rc=library~invokeArray(name,args); ec=0
  if rc<=0 then ec=library~invokeArray("ssl_get_error",.array~of(ssl,rc))
  owner~left
  return .array~of(rc,ec)
failed:
  owner~left
  raise propagate
::method closeObject
  expose owner
  use strict arg object
  owner~entered
  signal on syntax name failed
  if object<>.nil then if \object~closed then object~close
  owner~left
  return .nil
failed:
  owner~left
  raise propagate
::method closeLibrary
  expose owner
  use strict arg library
  owner~entered
  signal on syntax name failed
  if library<>.nil then library~close
  owner~left
  return .nil
failed:
  owner~left
  raise propagate

::class LdapTlsNativeGate public
::attribute invocationCount get
::attribute maxConcurrent get
::method init
  expose lane invocationCount active maxConcurrent
  lane=.LdapTlsNativeLane~new(self); invocationCount=0; active=0; maxConcurrent=0
::method entered
  expose active maxConcurrent
  active+=1; if active>maxConcurrent then maxConcurrent=active
::method left
  expose active
  if active>0 then active-=1
::method invoke unguarded
  expose lane invocationCount
  use strict arg library,name,args
  invocationCount+=1
  return lane~invoke(library,name,args)
::method sslStep unguarded
  expose lane invocationCount
  use strict arg library,name,args,ssl
  invocationCount+=1
  return lane~sslStep(library,name,args,ssl)
::method closeObject unguarded
  expose lane invocationCount
  use strict arg object
  invocationCount+=1
  return lane~closeObject(object)
::method closeLibrary unguarded
  expose lane invocationCount
  use strict arg library
  invocationCount+=1
  return lane~closeLibrary(library)

::class LdapTlsForeignLibrary public
::method init
  expose library gate
  use strict arg libraryArg,gateArg
  library=libraryArg; gate=gateArg
::method unknown unguarded
  expose library gate
  use strict arg name,args
  return gate~invoke(library,name,args)
::method sslStep unguarded
  expose library gate
  use strict arg name,args,ssl
  return gate~sslStep(library,name,args,ssl)
::method closeObject unguarded
  expose gate
  use strict arg object
  return gate~closeObject(object)
::method providerPath unguarded
  expose library
  return library~providerPath
::method threadingMode unguarded
  expose library
  return library~threadingMode
::method close unguarded
  expose library gate
  if library<>.nil then do; gate~closeLibrary(library); library=.nil; end


::requires "foreign.cls"
