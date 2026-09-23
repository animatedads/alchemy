/* Generic Wire projection: semantic selection identity -> source value -> target property.
   It knows no GTK, IMAP, timers, builder geometry, or protocol commands. */
::class WireSelectionProjection public
::method init
  expose resolver target property
  use strict arg resolver, target, property = "value"
::method selectionChanged
  expose resolver target property
  use strict arg event
  identity = event~context["identity"]
  value = resolver~valueForIdentity(identity)
  target~setProperty(property, value)
