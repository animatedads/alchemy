# Camera v0.20 Algorithm Relation Integration

The adapter in `integration/CameraCurrentConditionAlgorithmProvider.cls` demonstrates cross-component integration without copying CameraCore into HardWorld.

## Dependency boundary

The adapter does not contain:

```text
::requires 'CameraCore.cls'
```

It accepts an object implementing the public `CameraCurrentCondition` message surface.  The owning camera component is responsible for loading/creating that object.

This is intentional: Camera remains independently versioned and testable.

## Validated source

The integration was tested against the supplied Camera v0.20 package whose `MANIFEST.sha256` records:

```text
a091ff1bae0e2dc7d70e1a0cf6df35218942220110b0a229b9a07d23cd89828f  CameraCore.cls
```

The integration test uses CameraCore's actual transition/current-condition machinery to produce a `CONDITION_SHIFTED` result and then sends that object through the adapter.

## Output relations

`CAMERA_CURRENT_CONDITION` includes typed columns for:

```text
TIMESTAMP
DAY_CLASS
WINDOW_SECONDS
TRANSITION_COUNT
UNIQUE_TRANSITION_COUNT
EMPIRICAL_ENTROPY_BITS
BASELINE_ENTROPY_BITS
AVERAGE_CONTEXT_SURPRISE_BITS
EXCESS_SURPRISE_BITS
DOMINANT_TRANSITION_ID
DOMINANT_TRANSITION_SHARE
BASELINE_CONTEXT
METRIC_ASSESSMENT_COUNT
USABLE_METRIC_COUNT
ELEVATED_METRIC_COUNT
STRONGEST_METRIC_NAME
STRONGEST_METRIC_Z
CONDITION_STATE_CODE
CONDITION_STATE
```

`CAMERA_METRIC_SIGNALS` includes:

```text
METRIC_NAME
SAMPLE_COUNT
AVERAGE_Z
MAXIMUM_ABSOLUTE_Z
ELEVATED
BASELINE_CONTEXT
```

## Why this matters

The Camera algorithm and HardWorld rules are radically different internally, but NoSQLServer would receive them through the same provider/result envelope.

That is the desired proof of "algorithm as a table": common execution and provenance semantics without flattening domain schemas into a generic EAV table.
