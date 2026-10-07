/* No Alchemy, Queue Fabric, Foreign Runtime, or project dependencies. */

cat = .Animal~new("Mog", "cat", "miaow")
dog = .Animal~new("Rex", "dog", "woof")
owl = .Animal~new("Archimedes", "owl", "hoot")

say "constant:" cat~KINGDOM
say "animal:" cat~describe
say "method:" cat~speak

zoo = .AnimalCollection~new
zoo~add(cat)
zoo~add(dog)
zoo~add(owl)
say "collection-count:" zoo~count

do line over zoo~descriptions
  say "collection-item:" line
end

alarm = .Alarm~new("The animals would like breakfast")
reply = alarm~ring
say "python-callback-return:" reply
return "DEMO_OK"

::requires "animals.cls"
