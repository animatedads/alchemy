# Methodology Provider Contract

A methodology provider supplies executable implementations for one or more methodology specifications. The catalogue is intentionally provider-neutral.

## Provider responsibilities

A provider should expose:

- methodology ID(s) implemented;
- implementation/package identity and version;
- dependency requirements;
- supported input/output kinds;
- parameter schema and defaults;
- deterministic/probabilistic declaration;
- hardware/runtime requirements;
- qualification envelope;
- known deviations from the methodology specification;
- cost/performance hints;
- provenance callback able to describe an executed run.

## Dynamic discovery

Provider discovery is re-evaluated when the execution environment changes. A GPU model, native library, camera calibration, microphone array geometry, remote worker or Storage Fabric source becoming available can change which methodologies are executable.

A provider being available does not make it preferred. A provider being unavailable does not remove the methodology from the conceptual catalogue.

## Multiple providers

Several providers may implement the same methodology. A planning layer may A/B them, run them as independent reconstruction branches, or choose one based on qualification/cost constraints.

Implementation agreement is not independent evidence if the providers share the same model weights, optical flow, PSF estimate or preprocessing chain.

## Failure reporting

Fail closed with structured reason codes such as:

- `MISSING_INPUT_KIND`
- `MISSING_CALIBRATION`
- `NO_OBSERVATION_AUTHORITY`
- `INSUFFICIENT_SUPPORT`
- `DEGENERATE_GEOMETRY`
- `CLOCK_UNRESOLVED`
- `MODEL_DOMAIN_UNSUPPORTED`
- `RESOURCE_UNAVAILABLE`
- `QUALIFICATION_ENVELOPE_EXCEEDED`

Do not silently fall back to a semantically different method under the same methodology ID.
