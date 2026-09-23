# Crime Enterprise object dependency

This directory contains the ooRexx crime/investigation domain object model used by
the Wire3D investigation-space example. It is bundled explicitly so consumers and
code-review tools do not need to infer a dependency from `examples/domain`.

Authority rule: these are domain objects. Wire/Wire3D presents the same object
instances; it must not create parallel Wire3D crime-domain classes.
