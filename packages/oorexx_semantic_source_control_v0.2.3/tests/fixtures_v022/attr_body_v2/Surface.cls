::class Surface public
::attribute value get
  expose stored
  return stored + 0
::attribute value set
  expose stored
  use arg v
  stored = v
