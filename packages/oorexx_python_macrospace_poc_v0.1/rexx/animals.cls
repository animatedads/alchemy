::class Animal public
::constant KINGDOM "Animalia"
::attribute name
::attribute species
::attribute sound

::method init
  expose name species sound
  use strict arg name, species, sound

::method describe
  expose name species
  return name || " is a " || species

::method speak
  expose name sound
  return name || " says " || sound

::class AnimalCollection public
::method init
  expose animals
  animals = .array~new

::method add
  expose animals
  use strict arg animal
  animals~append(animal)
  return animals~items

::method count
  expose animals
  return animals~items

::method at
  expose animals
  use strict arg index
  return animals[index]

::method descriptions
  expose animals
  out = .array~new
  do animal over animals
    out~append(animal~describe)
  end
  return out

::class Alarm public
::attribute message

::method init
  expose message
  use strict arg message

::method ring
  expose message
  /* PYALARM is intentionally resolved through ooRexx Macrospace. */
  return PYALARM(message)
