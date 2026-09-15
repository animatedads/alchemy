/* Dependency-indexed object-state -> semantic slot projection. */
::requires "WireUIProtocol.cls"

::class WireUIProjection subclass AlchemyObject public
::method init
  expose dependencies derivedBindings
  self~init:super(.WireUIAlchemy~metadata("Dependency-indexed authoritative state to semantic UI projection"))
  dependencies = .table~new
  derivedBindings = .array~new

::method bind
  expose dependencies
  use arg stateKey, instanceId, slotName, transform = .nil
  rows = dependencies[stateKey]
  if rows == .nil then do
    rows = .array~new
    dependencies[stateKey] = rows
  end
  row = .table~new
  row["instanceId"] = instanceId
  row["slot"] = slotName
  row["transform"] = transform
  rows~append(row)
  return self

::method bindSlots
  expose dependencies
  use arg stateKey, instanceId, transform=.nil
  rows=dependencies[stateKey]
  if rows==.nil then do
    rows=.array~new
    dependencies[stateKey]=rows
  end
  row=.table~new
  row["instanceId"]=instanceId
  row["slotGroup"]=.true
  row["transform"]=transform
  rows~append(row)
  return self

::method projectChange
  expose dependencies
  use arg view, stateKey, newValue
  rows = dependencies[stateKey]
  patches = .array~new
  if rows == .nil then return patches
  do row over rows
    value = newValue
    if row["transform"] \== .nil then value = row["transform"]~call(newValue)
    isGroup=.false
    if row~hasIndex("slotGroup") then isGroup=row["slotGroup"]
    if isGroup then result=view~setSlots(row["instanceId"],value)
    else result = view~setSlot(row["instanceId"], row["slot"], value)
    if result~ok & result~value \== .nil then patches~append(result~value)
  end
  return patches


/* Register a projection whose output depends on several authoritative state
   keys. transform~call(stateSnapshot, changedKeys) must return a table keyed by
   instanceId; each value is a slot-update table. The view applies the combined
   output under one revision. */
::method bindDerived
  expose derivedBindings
  use arg stateKeys, transform
  if stateKeys==.nil | \stateKeys~isA(.Array) | stateKeys~items=0 then return .WireUIResult~failure("DERIVED_DEPENDENCIES_INVALID")
  if transform==.nil | \transform~hasMethod("CALL") then return .WireUIResult~failure("DERIVED_TRANSFORM_INVALID")
  row=.table~new
  row["stateKeys"]=self~copyArray(stateKeys)
  row["transform"]=transform
  derivedBindings~append(row)
  return .WireUIResult~success(self,"DERIVED_BINDING_ADDED")

::method projectDerivedGroup
  expose derivedBindings
  use arg view, stateSnapshot, changedKeys
  if stateSnapshot==.nil | \stateSnapshot~hasMethod("HASINDEX") then return .WireUIResult~failure("STATE_SNAPSHOT_INVALID")
  if changedKeys==.nil | \changedKeys~isA(.Array) then return .WireUIResult~failure("CHANGED_KEYS_INVALID")
  combined=.table~new
  do row over derivedBindings
    interested=.false
    do dep over row["stateKeys"]
      do changed over changedKeys
        if dep=changed then interested=.true
      end
    end
    if \interested then iterate
    output=row["transform"]~call(stateSnapshot,changedKeys)
    if output==.nil | \output~hasMethod("HASINDEX") then return .WireUIResult~failure("DERIVED_TRANSFORM_RESULT_INVALID")
    do instanceId over output~allIndexes
      slots=output[instanceId]
      if slots==.nil | \slots~hasMethod("HASINDEX") then return .WireUIResult~failure("DERIVED_SLOT_GROUP_INVALID",instanceId)
      target=combined[instanceId]
      if target==.nil then do
        target=.table~new
        combined[instanceId]=target
      end
      do slotName over slots~allIndexes
        if target~hasIndex(slotName) & target[slotName] \== slots[slotName] then return .WireUIResult~failure("DERIVED_SLOT_CONFLICT",instanceId"/"slotName)
        target[slotName]=slots[slotName]
      end
    end
  end
  if combined~items=0 then return .WireUIResult~success(.nil,"NO_DERIVED_CHANGE")
  return view~setSlotsAcross(combined)

::method copyArray private
  use arg source
  a=.array~new
  do v over source; a~append(v); end
  return a

::requires "WireUIAlchemy.cls"
