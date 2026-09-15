/* MethodInterposition.cls - cooperative ooRexx per-object method interposition
 *
 * This is deliberately an ooRexx object/method facility rather than a generic
 * proxy framework.  A participating object owns the SETMETHOD/UNSETMETHOD
 * operations on its own method dictionary.  One physical wrapper is installed
 * per method and any number of cooperating providers register lightweight
 * interceptors behind it.
 *
 * With no providers, no wrapper exists.  Provider lists are replaced as whole
 * arrays when configuration changes so an executing invocation sees either the
 * previous complete list or the replacement complete list.
 */

::class MethodInterpositionParticipant public mixinclass Object

/* Register (or replace) one provider for one semantic method.  The target
 * object performs the actual SETMETHOD operation, preserving ooRexx's method
 * authority boundary. */
::method __methodInterpositionAdd public
  expose __miSlots __miCounter
  use strict arg methodName, providerId, interceptor, priority = 100
  methodName = methodName~string~translate
  providerId = providerId~string
  if providerId = "" then raise syntax 88.900 array("Method interposition provider id must not be empty")
  if interceptor == .nil then raise syntax 88.900 array("Method interposition interceptor must not be NIL")
  if \interceptor~hasMethod("BEFORE") | \interceptor~hasMethod("AFTER") | \interceptor~hasMethod("FAILURE") then -
    raise syntax 88.900 array("Method interposition interceptor requires BEFORE, AFTER and FAILURE")

  if \__miSlots~isA(.Table) then __miSlots = .table~new
  if \datatype(__miCounter, "N") then __miCounter = 0
  slot = __miSlots[methodName]
  if slot == .nil then do
    effective = self~__methodInterpositionEffectiveMethod(methodName)
    if effective == .nil then raise syntax 88.900 array("Interposition target method missing:" self~class~id || "~" || methodName)
    if effective~isPrivate then raise syntax 88.900 array("Interposition cannot wrap private method:" methodName)
    if effective~isProtected then raise syntax 88.900 array("Interposition cannot wrap protected method:" methodName)
    if effective~hasMethod("ISPACKAGE") then if effective~isPackage then raise syntax 88.900 array("Interposition cannot wrap package method:" methodName)

    priorObjectMethod = self~sendWith(.array~of("INSTANCEMETHOD", .Object), .array~of(methodName))
    hadObjectMethod = priorObjectMethod \== .nil
    restoreMethod = .nil
    if hadObjectMethod then restoreMethod = priorObjectMethod~copy

    __miCounter = __miCounter + 1
    alias = "__MI_ORIGINAL_" || __miCounter
    saved = effective~copy
    saved~setPrivate
    self~sendWith(.array~of("SETMETHOD", .Object), .array~of(alias, saved, "OBJECT"))

    body = .array~new
    body~append('args=arg(1,"A")')
    body~append('__miInvocation=self~__methodInterpositionBegin("' || methodName || '",args)')
    body~append('if __miInvocation==.nil then return self~sendWith("' || alias || '",args)')
    body~append('signal on syntax name __miFailure')
    body~append('__miResult=self~sendWith("' || alias || '",args)')
    body~append('signal off syntax')
    body~append('self~__methodInterpositionAfter("' || methodName || '",__miInvocation,__miResult)')
    body~append('return __miResult')
    body~append('__miFailure:')
    body~append('__miCondition=condition("O")')
    body~append('self~__methodInterpositionFailure("' || methodName || '",__miInvocation,__miCondition)')
    body~append('raise propagate')
    wrapper = .method~new(methodName, body)
    if \effective~isGuarded then wrapper~setUnguarded

    slot = .MethodInterpositionSlot~new(methodName, alias, hadObjectMethod, restoreMethod, wrapper)
    __miSlots[methodName] = slot
    self~sendWith(.array~of("SETMETHOD", .Object), .array~of(methodName, wrapper, "OBJECT"))
  end

  slot~addProvider(providerId, interceptor, priority)
  return slot

/* Remove one provider.  The physical method wrapper disappears only when the
 * final cooperating provider leaves. */
::method __methodInterpositionRemove public
  expose __miSlots
  use strict arg methodName, providerId
  methodName = methodName~string~translate
  providerId = providerId~string
  if \__miSlots~isA(.Table) then return .false
  slot = __miSlots[methodName]
  if slot == .nil then return .false
  removed = slot~removeProvider(providerId)
  if \removed then return .false
  if slot~providerCount > 0 then return .true

  current = self~sendWith(.array~of("INSTANCEMETHOD", .Object), .array~of(methodName))
  if \slot~ownsMethod(current) then -
    raise syntax 88.900 array("Method interposition ownership lost before final release:" self~class~id || "~" || methodName)

  self~sendWith(.array~of("UNSETMETHOD", .Object), .array~of(methodName))
  if slot~hadObjectMethod then do
    restored = slot~restoreMethod~copy
    self~sendWith(.array~of("SETMETHOD", .Object), .array~of(methodName, restored, "OBJECT"))
  end
  self~sendWith(.array~of("UNSETMETHOD", .Object), .array~of(slot~alias))
  __miSlots~remove(methodName)
  return .true

/* Called only by an installed wrapper.  It is unguarded so adding diagnostic
 * instrumentation does not accidentally serialize an otherwise unguarded
 * application method. */
::method __methodInterpositionBegin public unguarded
  expose __miSlots
  use strict arg methodName, arguments
  if \__miSlots~isA(.Table) then return .nil
  slot = __miSlots[methodName~string~translate]
  if slot == .nil then return .nil
  return slot~begin(self, arguments)

::method __methodInterpositionAfter public unguarded
  use strict arg methodName, invocation, result
  if invocation == .nil then return .true
  invocation~after(self, methodName~string~translate, result)
  return .true

::method __methodInterpositionFailure public unguarded
  use strict arg methodName, invocation, conditionObject
  if invocation == .nil then return .true
  invocation~failure(self, methodName~string~translate, conditionObject)
  return .true

/* Introspection is intentionally structural: it exposes provider ids and
 * wrapper integrity, not interceptor objects. */
::method methodInterpositionStatus public
  expose __miSlots
  use strict arg methodName = ""
  out = .directory~new
  if \__miSlots~isA(.Table) then do
    out["physical_wrappers"] = 0
    out["methods"] = .array~new
    return out
  end
  methods = .array~new
  if methodName~string = "" then names = __miSlots~allIndexes
  else names = .array~of(methodName~string~translate)
  do name over names
    slot = __miSlots[name]
    if slot == .nil then iterate
    rec = .directory~new
    rec["method"] = name
    rec["provider_count"] = slot~providerCount
    rec["providers"] = slot~providerIds
    rec["provider_details"] = slot~providerDetails
    rec["had_object_method"] = slot~hadObjectMethod
    current = self~sendWith(.array~of("INSTANCEMETHOD", .Object), .array~of(name))
    rec["wrapper_integrity"] = slot~ownsMethod(current)
    ignore = methods~append(rec)
  end
  out["physical_wrappers"] = methods~items
  out["methods"] = methods
  return out

::method __methodInterpositionEffectiveMethod private
  use strict arg methodName
  objectMethod = self~sendWith(.array~of("INSTANCEMETHOD", .Object), .array~of(methodName))
  if objectMethod \== .nil then return objectMethod
  supplier = self~sendWith(.array~of("CLASS", .Object), .array~new)~methods
  do while supplier~available
    if supplier~index~string~translate = methodName then return supplier~item
    supplier~next
  end
  return .nil


::class MethodInterpositionSlot public
::attribute methodName get
::attribute alias get
::attribute hadObjectMethod get
::attribute restoreMethod get
::attribute wrapperMethod get

::method init
  expose methodName alias hadObjectMethod restoreMethod wrapperMethod providers
  use strict arg methodName, alias, hadObjectMethod, restoreMethod, wrapperMethod
  methodName = methodName~string~translate
  alias = alias~string
  hadObjectMethod = hadObjectMethod
  restoreMethod = restoreMethod
  wrapperMethod = wrapperMethod
  providers = .array~new

/* Configuration mutation is guarded.  Replace the array rather than mutating
 * the published instance so unguarded invocations see a complete snapshot. */
::method addProvider public
  expose providers
  use strict arg providerId, interceptor, priority = 100
  if \datatype(priority, "N") then raise syntax 88.900 array("Method interposition priority must be numeric")
  replacement = .array~new
  fresh = .MethodInterpositionProvider~new(providerId, interceptor, priority)
  inserted = .false
  /* Provider ordering is configuration-time work.  Lower priorities execute
   * BEFORE higher priorities; completion/failure runs in reverse.  Equal
   * priorities retain registration order.  Replacing a provider removes its
   * old record first, so changing priority also repositions it atomically. */
  do rec over providers
    if rec~providerId = providerId then iterate
    if \inserted & priority < rec~priority then do
      replacement~append(fresh)
      inserted = .true
    end
    replacement~append(rec)
  end
  if \inserted then replacement~append(fresh)
  providers = replacement
  return .true

::method removeProvider public
  expose providers
  use strict arg providerId
  replacement = .array~new
  removed = .false
  do rec over providers
    if rec~providerId = providerId then removed = .true
    else replacement~append(rec)
  end
  if removed then providers = replacement
  return removed

::method ownsMethod public unguarded
  expose wrapperMethod
  use strict arg candidate
  if candidate == .nil then return .false
  if \candidate~hasMethod("SOURCE") then return .false
  expected = wrapperMethod~source
  actual = candidate~source
  if expected~items \= actual~items then return .false
  do i = 1 to expected~items
    if expected[i] \== actual[i] then return .false
  end
  return .true

::method providerCount public unguarded
  expose providers
  return providers~items

::method providerIds public unguarded
  expose providers
  snapshot = providers
  ids = .array~new
  do rec over snapshot
    ids~append(rec~providerId)
  end
  return ids

::method providerDetails public unguarded
  expose providers
  snapshot = providers
  details = .array~new
  do rec over snapshot
    d = .directory~new
    d["provider_id"] = rec~providerId
    d["priority"] = rec~priority
    details~append(d)
  end
  return details

::method begin public unguarded
  expose providers methodName
  use strict arg receiver, arguments
  snapshot = providers
  active = .nil
  do rec over snapshot
    token = rec~interceptor~before(receiver, methodName, arguments)
    if token == .nil then iterate
    if active == .nil then active = .array~new
    active~append(.MethodInterpositionActivation~new(rec~providerId, rec~interceptor, token))
  end
  if active == .nil then return .nil
  return .MethodInterpositionInvocation~new(active)


::class MethodInterpositionProvider public
::attribute providerId get
::attribute interceptor get
::attribute priority get
::method init
  expose providerId interceptor priority
  use strict arg providerId, interceptor, priority = 100
  providerId = providerId~string
  interceptor = interceptor
  priority = priority


::class MethodInterpositionActivation public
::attribute providerId get
::attribute interceptor get
::attribute token get
::method init
  expose providerId interceptor token
  use strict arg providerId, interceptor, token
  providerId = providerId~string
  interceptor = interceptor
  token = token


::class MethodInterpositionInvocation public
::method init
  expose activations
  use strict arg activations
  activations = activations

/* Completion/failure run in reverse provider order, matching nested around-
 * method semantics while requiring only one physical wrapper. */
::method after public unguarded
  expose activations
  use strict arg receiver, methodName, result
  do i = activations~items to 1 by -1
    rec = activations[i]
    rec~interceptor~after(receiver, methodName, rec~token, result)
  end
  return .true

::method failure public unguarded
  expose activations
  use strict arg receiver, methodName, conditionObject
  do i = activations~items to 1 by -1
    rec = activations[i]
    rec~interceptor~failure(receiver, methodName, rec~token, conditionObject)
  end
  return .true
