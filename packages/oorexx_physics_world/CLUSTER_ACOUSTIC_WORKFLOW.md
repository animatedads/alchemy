# F11 acoustic Cluster workflow — dev49

The reverse-engineering workload uses the existing `cluster.object.peer/0.1`
object-movement contract. Physics and signal objects remain ordinary ooRexx
objects and do not know whether they execute locally or on a Cluster member.

## Work unit

The unit of work is one candidate source location plus one complete vehicle
trajectory/direction. A 20 ms trajectory is not decomposed into independent
cluster messages because pitch, cadence, reflected power, reflection delay and
overlap are coupled through time.

## Destination-local data

Each member publishes `f11-acoustic-context`. The task receives it through a
`LOCAL_REF`. Building/rear geometry, PCM, FFT/STFT state, caches and other
large objects remain resident. The object envelope contains only candidate
coordinates, direction, timing parameters and signal identity.

## Batch planning — dev49

`F11AcousticCandidateBatchPlan` creates explicit candidate tasks.
`F11AcousticBatchPlanner~assignRoundRobin()` creates deterministic assignment
evidence without claiming that round-robin is performance-optimal.
`F11AcousticClusterBatchRunner` stages each object, moves it through the
existing ownership-fenced MOVE protocol, invokes it once at the assigned node,
and retains one compact success/failure record.

This is intentionally sequential at the orchestration seam. Queue Fabric or a
higher scheduler may perform multiple independent assignments concurrently
without changing task semantics.

## Compact evidence result

`physics.f11.candidate-summary/2` retains compact scalar evidence and references
for:

- static FD-FC delay;
- static reconstruction overlap lag;
- FC and FD pitch curves;
- FC and FD cadence/apparent-speed curves;
- FC and FD reflected-power curves;
- FC and FD reflection-delay curves;
- full overlap-score curve;
- FC and FD vehicle-subtracted residual evidence.

Heavy waveform/spectral products do not travel in the cluster response.

## Qualification

The dev49 loopback qualification fans four whole-trajectory Room-F candidates
across three object hosts. It proves deterministic assignment, ownership
transfer, destination-local context resolution, v2 evidence summaries, exact
one-call execution per candidate, and complete release from the staging host.
