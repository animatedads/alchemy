/* Return real ooRexx objects to the native bridge. */
use strict arg operation, a = .nil, b = .nil, c = .nil
select
  when operation == 'ANIMAL' then return .Animal~new(a, b, c)
  when operation == 'COLLECTION' then return .AnimalCollection~new
  when operation == 'GUARDED' then return .GuardedAnimal~new(a)
  when operation == 'EXISTINGUNKNOWN' then do
    use arg , handle, methods
    return .ExistingUnknownThing~new(handle, methods)
  end
  when operation == 'ARGPROBE' then return .ArgumentProbe~new
  when operation == 'SLOTARRAY' then do
    a = .array~new(4)
    /* index 1 deliberately absent */
    a[2] = .nil
    a[3] = ""
    a[4] = "hello"
    return a
  end
  when operation == 'STEM' then do
    stem = .stem~new('ANIMAL.')
    stem['NAME'] = 'Monty'
    stem['SPECIES'] = 'parrot'
    stem['FOOD.1'] = 'biscuit'
    stem['FOOD.2'] = 'seed'
    return stem
  end
  otherwise raise syntax 93.900 array ('unknown factory operation', operation)
end
::requires 'animals.cls'


::class ArgumentProbe public
::method probe
  if \arg(1, "E") then return "OMITTED"
  use arg value
  if value == .nil then return "NIL"
  if value == "" then return "EMPTY"
  return "VALUE:" || value

::requires 'existing_unknown.rex'
