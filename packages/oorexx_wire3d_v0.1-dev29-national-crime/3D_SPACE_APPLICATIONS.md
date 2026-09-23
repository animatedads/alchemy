# Wire3D 3D Space Applications

A `Wire3DSpaceApp` is a spatial projection/mount boundary around an existing application.
It is not a second application framework and does not own application truth.

Founding invariant:

> Same application. Same objects. Same behaviour. Same authority. Different space.

A 3D projection may use radically different composition, navigation and interaction from
phone, desktop or conventional Wire renderers. Spatial interaction must resolve to the
same semantic action and ordinary ooRexx behaviour used by the application elsewhere.
There are deliberately no `vrReply`, `vrBook`, or `threeDDebug` behaviour methods.

`expose()` records the already-authorised application object/capability made available to
the spatial projection. `project()` gives that object a spatial representation without
copying or replacing it. `bind()` maps a semantic action to existing ooRexx behaviour.
`activate()` creates a renderer-neutral application event and fires that binding.

The renderer remains free to make mail look like correspondence rooms, a debugger like a
runtime graph, a database like navigable relationships, or FlyLo like a spatial journey.
Those presentation choices cannot reinterpret application semantics or acquire authority.

## dev19 — semantic equivalence qualification

The first mail spatial qualification fixture deliberately gives the renderer a
spatial vocabulary that does not resemble a conventional mail UI:

```
conventional list/pane activation ----> message.open ----> openMessage(event)
spatial.enter-correspondence ----------> message.open ----> openMessage(event)
```

The two routes must produce the same semantic trace.  The trace contains the
semantic action, stable mail identity and authoritative effect; it deliberately
contains no click/tap/gesture, camera, geometry, DOM, native widget or WebGL
facts.  This is the qualification boundary for "same application, same code,
different space".

The fixture uses a bounded representative mail object rather than importing a
mail backing store into Wire3D.  Large collections remain governed by the Wire
bounded-window/source-authority rules.

### ooRexx Directory iteration

Wire3D uses native ooRexx Directory semantics: `do key over directory` iterates
indexes; the associated object is obtained with `directory[key]`.  This is
intentional because semantic identity and value are both required when
serialising bindings, entry points, mounts and exposed application objects.
