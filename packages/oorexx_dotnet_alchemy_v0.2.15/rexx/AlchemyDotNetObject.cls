/* AlchemyDotNetObject.cls - CLR participation in the shared Alchemy foreign-object pattern. */
::class AlchemyDotNetObject public subclass AlchemyForeignObject inherit MethodInterpositionParticipant
::attribute foreignHandle get
/* Bind this Rexx proxy to one stable CLR registry handle and initialise the shared interposition coordinator. */
::method init
  expose foreignHandle
  use strict arg foreignHandle
  self~init:super
  self~initMethodInterposition
  self~nativeInit(foreignHandle)
/* Identify the owning foreign runtime without weakening CLR System.Type authority. */
::method foreignRuntime
  return 'dotnet'
::method nativeInit external "LIBRARY alchemy_clr_package dotnet_init"
::method alchemyHandle external "LIBRARY alchemy_clr_package dotnet_handle"
::method dotNetIsA external "LIBRARY alchemy_clr_package dotnet_isa"
/* Return the authoritative CLR System.Type projection for this object's current CLR type. */
::method dotNetClass
  return self~nativeInvoke("DOTNETCLASS", .array~new)
/* Project otherwise-unknown Rexx messages into CLR reflection dispatch. Existing Rexx methods win first. */
::method unknown
  use strict arg messageName, arguments
  return self~nativeInvoke(messageName, arguments)

/* Register a semantic Rexx override as a cooperative provider; never stash or replace the CLR target. */
::method installRexxMemberOverride
  use strict arg memberName, providerId, interceptor, priority = 700
  return self~__methodInterpositionAdd(memberName, providerId, interceptor, priority)
/* Remove only this provider. The coordinator then reveals whatever CLR target is current at dispatch time. */
::method removeRexxMemberOverride
  use strict arg memberName, providerId
  return self~__methodInterpositionRemove(memberName, providerId)
/* Expose coordinator state for diagnostics/qualification without granting target ownership. */
::method dotNetMemberInterpositionStatus
  use strict arg memberName
  return self~methodInterpositionStatus(memberName)
::method nativeInvoke0 external "LIBRARY alchemy_clr_package dotnet_invoke0"
::method nativeInvoke external "LIBRARY alchemy_clr_package dotnet_invoke"

::class AlchemyDotNetClass public subclass AlchemyForeignObject
::attribute foreignHandle get
::method init
  expose foreignHandle
  use strict arg foreignHandle
  self~init:super
  self~nativeInit(foreignHandle)
::method foreignRuntime
  return 'dotnet'
::method nativeInit external "LIBRARY alchemy_clr_package dotnet_init"
::method alchemyHandle external "LIBRARY alchemy_clr_package dotnet_handle"
::method dotNetIsA external "LIBRARY alchemy_clr_package dotnet_isa"
::method unknown
  use strict arg messageName, arguments
  return self~nativeInvoke(messageName, arguments)
::method nativeInvoke external "LIBRARY alchemy_clr_package dotnet_invoke"
::method name
  return self~nativeInvoke("NAME", .array~new)
::method fullName
  return self~nativeInvoke("FULLNAME", .array~new)
::method baseType
  return self~nativeInvoke("BASETYPE", .array~new)
::method isInstance
  use strict arg object
  return self~nativeInvoke("ISINSTANCE", .array~of(object))
::method isSubclassOf
  use strict arg type
  return self~nativeInvoke("ISSUBCLASSOF", .array~of(type))
::method isAssignableFrom
  use strict arg type
  return self~nativeInvoke("ISASSIGNABLEFROM", .array~of(type))
::requires 'AlchemyForeignObject.cls'

::class ExistingUnknownDotNetThing public subclass AlchemyForeignObject
::attribute foreignHandle
::attribute originalUnknownAlias
::attribute projectedNames
::method init
  expose foreignHandle originalUnknownAlias projectedNames
  use strict arg foreignHandle, projectedNames
  self~init:super
  self~nativeInit(foreignHandle)
  self~installDotNetProjection(projectedNames)
::method known
  return "REXX-KNOWN"
::method unknown
  use strict arg messageName, arguments
  return "ORIGINAL-UNKNOWN:" || messageName || ":" || arguments~items
::method bridgeUnknown
  expose projectedNames
  use strict arg messageName, arguments
  if wordpos(messageName~upper, projectedNames) > 0 then return self~nativeInvoke(messageName, arguments)
  return self~foreignUnknownFallback(messageName, arguments)
::method foreignRuntime
  return 'dotnet'
::method installDotNetProjection
  expose projectedNames
  use strict arg names
  projectedNames = names~upper
  return self~installForeignUnknownComposition("BRIDGEUNKNOWN")
::method nativeInit external "LIBRARY alchemy_clr_package dotnet_init"
::method nativeInvoke0 external "LIBRARY alchemy_clr_package dotnet_invoke0"
::method nativeInvoke external "LIBRARY alchemy_clr_package dotnet_invoke"
::method alchemyHandle external "LIBRARY alchemy_clr_package dotnet_handle"

::requires 'MethodInterposition.cls'
