/* Return real ooRexx objects to the native bridge. */
use strict arg operation, a = .nil, b = .nil, c = .nil
select
  when operation == 'ANIMAL' then return .Animal~new(a, b, c)
  when operation == 'COLLECTION' then return .AnimalCollection~new
  when operation == 'GUARDED' then return .GuardedAnimal~new(a)
  otherwise raise syntax 93.900 array ('unknown factory operation', operation)
end
::requires 'animals.cls'
