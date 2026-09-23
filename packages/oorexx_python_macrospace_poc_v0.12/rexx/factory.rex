/* Return real ooRexx objects to the native bridge. */
use strict arg operation, a = .nil, b = .nil, c = .nil
select
  when operation == 'ANIMAL' then return .Animal~new(a, b, c)
  when operation == 'COLLECTION' then return .AnimalCollection~new
  when operation == 'GUARDED' then return .GuardedAnimal~new(a)
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
