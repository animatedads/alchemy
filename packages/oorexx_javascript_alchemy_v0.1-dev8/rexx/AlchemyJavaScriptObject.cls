::class AlchemyJavaScriptObject public subclass AlchemyForeignObject

::method init
  use strict arg runtime, handle
  self~nativeInit(runtime, handle)

::method handle
  return self~nativeHandle

::method typeOf
  return self~nativeTypeOf

::method instanceOf
  use strict arg constructorName
  return self~nativeInstanceOf(constructorName)

/* Default foreign dispatch. */
::method unknown
  use strict arg messageName, arguments
  return self~nativeInvoke(messageName, arguments)

/*
 * Project a stable public selector once. The trampoline remains the public
 * ooRexx Method object even if the backing JavaScript property changes.
 */
::method projectJavaScriptSelector public
  expose __jsProjected
  use strict arg name
  name = name~string~translate
  if __jsProjected == .nil then __jsProjected = .directory~new
  if __jsProjected~hasIndex(name) then return __jsProjected[name]
  source = 'use arg arguments=(arg(1,"A")); return self~__javascriptDispatchProjected("' || name || '", arguments)'
  trampoline = .method~new(name, source)
  self~setMethod(name, trampoline, "OBJECT")
  rec = .directory~new
  rec["name"] = name
  rec["trampoline"] = trampoline
  rec["overrideAlias"] = .nil
  __jsProjected[name] = rec
  return rec

::method installJavaScriptRexxOverride public
  expose __jsProjected
  use strict arg name, methodObject
  name = name~string~translate
  rec = self~projectJavaScriptSelector(name)
  alias = '__JSREXXOVERRIDE_' || name
  self~setMethod(alias, methodObject, "OBJECT")
  rec["overrideAlias"] = alias
  return rec

::method removeJavaScriptRexxOverride public
  expose __jsProjected
  use strict arg name
  name = name~string~translate
  if __jsProjected == .nil then return .false
  if \__jsProjected~hasIndex(name) then return .false
  rec = __jsProjected[name]
  alias = rec["overrideAlias"]
  if alias \== .nil then self~unsetMethod(alias)
  rec["overrideAlias"] = .nil
  return .true

::method __javascriptDispatchProjected private unguarded
  expose __jsProjected
  use strict arg name, arguments
  if __jsProjected \== .nil, __jsProjected~hasIndex(name) then do
    alias = __jsProjected[name]["overrideAlias"]
    if alias \== .nil then return self~sendWith(alias, arguments)
  end
  return self~nativeInvoke(name, arguments)

::method javascriptProjectionState public
  expose __jsProjected
  if __jsProjected == .nil then return .directory~new
  return __jsProjected

::method nativeInit external "LIBRARY alchemy_javascript_package javascript_init"
::method nativeHandle external "LIBRARY alchemy_javascript_package javascript_handle"
::method nativeTypeOf external "LIBRARY alchemy_javascript_package javascript_typeof"
::method nativeInstanceOf external "LIBRARY alchemy_javascript_package javascript_instanceof"
::method nativeInvoke external "LIBRARY alchemy_javascript_package javascript_invoke"

::requires 'AlchemyForeignObject.cls'
