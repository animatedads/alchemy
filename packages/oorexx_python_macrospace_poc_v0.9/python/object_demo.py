from objects import Animal, AnimalCollection

mog = Animal.new("Mog", "cat", "miaow")
assert mog.name == "Mog"
assert mog.species == "cat"
assert mog.sound == "miaow"
assert mog.describe() == "Mog is a cat"
assert mog.speak() == "Mog says miaow"
print("python-proxy-animal:", mog.name, mog.describe(), mog.speak())

animals = AnimalCollection.new()
animals.add(mog)
animals.add(Animal.new("Rex", "dog", "woof"))
animals.add(Animal.new("Archimedes", "owl", "hoot"))
assert len(animals) == 3
print("python-iterates-rexx-collection:")
for animal in animals:
    print(" ", animal.describe())
assert [a.name for a in animals] == ["Mog", "Rex", "Archimedes"]
print("OBJECT PROXY POC PASS")
