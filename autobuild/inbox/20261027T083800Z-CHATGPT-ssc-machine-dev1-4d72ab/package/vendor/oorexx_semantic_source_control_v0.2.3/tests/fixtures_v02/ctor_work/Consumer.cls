::class MachineHarness public
::method run
  machine = .IBM4361Machine~new(1048576)
  return machine

::class IBM370PSW public
::method init
  self~init:super
  return self
