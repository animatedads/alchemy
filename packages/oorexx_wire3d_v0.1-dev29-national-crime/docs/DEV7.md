# Wire3D 0.1-dev7

## System JSON ownership

Wire3D no longer contains a private JSON encoder.  The ooRexx Rexx Extensions
library already owns JSON text serialization through `json.cls` and its public
`.JSON` class.

Wire3D owns only the semantic-to-wire-object conversion: snapshots and deltas
are represented as neutral ooRexx `.Directory`, `.Array`, and scalar trees.
Text serialization is delegated to:

```rexx
json = .JSON~new
text = json~toJSON(wireObject)
wireObject = json~fromJSON(text)

::requires 'json.cls'
```

This follows the documented `json.cls` API (`init`, `toJSON`, `fromJSON`) and
removes duplicate ownership of quoting, escaping, numeric serialization and
JSON parsing from Wire3D.

The ooRexx documentation notes that this JSON implementation does not transform
Unicode `\\uXXXX` escape sequences. Wire3D therefore does not claim that
capability unless separately qualified against the selected runtime.

## Qualification change

`tests/test_core.rex` now exercises a snapshot through the real system
`.JSON~toJSON` and `.JSON~fromJSON` path and checks the protocol and scene ID
after round-trip.  `examples/corporate_city.rex` also uses the system class.
