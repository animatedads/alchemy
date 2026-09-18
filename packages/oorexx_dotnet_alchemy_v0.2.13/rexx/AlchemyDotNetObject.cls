/* AlchemyDotNetObject.cls - CLR participation in the shared Alchemy foreign-object pattern. */
::class AlchemyDotNetObject public subclass AlchemyForeignObject
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
::method dotNetClass
  return self~nativeInvoke("DOTNETCLASS", .array~new)
::method unknown
  use strict arg messageName, arguments
  return self~nativeInvoke(messageName, arguments)
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
