# Audio V9 transient-reflector sphere v0.1

## Authority

Frozen decoded audio and its timing/provenance remain measurement authority.
Vehicle video supplies occupancy and geometry context only.  It cannot create
an acoustic path, speech, transcript, source identity or clock shift.

## Moving-surface model

For source `S`, receiver `M`, tracked reflector point `R(t)`, sound speed `c`
and sample rate `fs`:

`d_direct = |S-M|`

`d_reflected(t) = |S-R(t)| + |R(t)-M|`

`delay_samples(t) = max(0,d_reflected(t)-d_direct) * fs / c`

The predicted curve is compared with independently measured acoustic-path
delays.  Geometry may rank or falsify candidates but does not admit them.

## Competing hypotheses

- H0_NO_CHANGE: no audio-supported path change.
- H1_REFLECTION: an audio-authoritative delay follows the moving prediction.
- H2_BLOCKAGE: the direct path falls without an admitted reflected path.
- H3_SELF_NOISE: vehicle energy is present without an admitted speech-coherent path.

## Virtual microphone

A virtual-microphone candidate is a delay-corrected physical-path plan.  It is
AVAILABLE only after at least three monotonically timed H1 observations pass
the acoustic, geometry and delay-residual gates.  It remains derived evidence
and cannot replace frozen samples or become transcript authority.

## Clouds and atmospheric layers

Clouds are not assumed to be hard acoustic mirrors.  Cloud-correlated changes
are modelled separately as atmospheric refraction, ducting, absorption or weak
volume scattering unless a stable elevated return is actually measured.

## Continuity

Executable candidate: `audio_v9_voice_recovery_v0.1-dev19.zip`, SHA-256
`3f0ae48bdbbb676368f3b5ccf05d0999fc15346dfc4e60b01772dc6cb701faf1`.
It preserves dev18 and adds `AudioV9TransientReflectorTrajectory.cls`, its
synthetic authority test, the dev19 qualification record and this doctrine.
Autobuilder was not running on 2026-10-29.  Native ooRexx 5.3.0 r13196 runtime
qualification and real FC/FD trajectory fitting remain pending.
