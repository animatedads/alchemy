# Dual-camera native-cadence motion probe

Inputs:
- `1000060609.mp4` — 1080x1920, 29.9729069 fps, 1641 frames.
- `VID_20260923_050113.mp4` — 1080x1920, 30.0390477 fps, 1615 frames.

The cameras were carried simultaneously, one in each hand, approximately level.
They are therefore independent moving cameras with strongly correlated gross
motion, not a rigid calibrated stereo pair.

Qualification probe:
- processed every source frame (no 5 fps temporal decimation);
- used a 96x171 reduced 5-bit luminance proxy for this motion-only probe;
- tracked frame-to-frame local features and fitted robust image-motion summaries;
- searched integer frame lags over +/-180 frames.

Consensus alignment is `A[22+i] ~= B[i]`, i.e. Camera A starts about 22 frames
(~0.734 s at A cadence) before the common content seen by Camera B.

Aligned full-sequence motion correlations at that lag:
- horizontal image drift: ~0.972
- vertical image drift: ~0.931
- in-plane rotation: ~0.906
- motion magnitude: ~0.972
- expansion/log-scale: ~0.529

The strong agreement independently confirms that the two files contain the same
physical traversal.  Expansion agreement is weaker, which is expected for two
hand-held cameras with different instantaneous pose/baseline.

The 5-bit luminance reduction is only a qualification proxy.  The product
contract remains the Vision/V5V surface and palette authority; the solver is
written against motion/geometry evidence rather than this probe implementation.

Physical path policy used by dev7:
- max camera translation: 3 m/s;
- max angular rate: 360 deg/s;
- 90 degrees in 0.5 s = 180 deg/s and is therefore valid;
- every pose must lie on accessible floor;
- transitions through explicit wall segments are invalid; openings are gaps in
  those wall segments.
