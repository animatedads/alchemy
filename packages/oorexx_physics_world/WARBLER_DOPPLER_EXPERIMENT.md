# F11 deterministic warbler / vehicle Doppler experiment

The stationary calibration source is deliberately known and persistent.  Default pattern:

- 500 Hz for 80 ms + 20 ms gap
- 1000 Hz for 80 ms + 20 ms gap
- 2000 Hz for 80 ms + 20 ms gap
- 1000 Hz for 80 ms + 20 ms gap
- 400 ms cycle (2.5 cycles/s)
- fixed 2.4 s source duration

The vehicle remains the continuous 40 km/h trajectory introduced in dev36.  The default observation interval is 20 ms (~0.222 m of travel), while x=-4,2,8,14,20 m remain named reference gates rather than teleport positions.

For a stationary source reflected by the moving vehicle, the same Doppler time-warp ratio must explain both the observed tone frequency and the apparent warbler/pip cadence.  That is a useful consistency test against unrelated vehicle tones.

Known vehicle emission is a separate model contribution.  Any subtraction is performed in pressure (Pa) sample space after applying the modeled vehicle Doppler/path response.  dB values are reporting quantities only and are never arithmetically subtracted as waveforms.

The experiment output is designed for reverse inference, retaining the measurements independently rather than selecting a location:

- FC/FD source-to-receiver timing evidence
- moving-reflector path delay and level
- pitch Doppler ratio
- cadence/speed Doppler ratio
- continuous vehicle position/time
- vehicle-source Doppler frequencies
- reference gate crossing labels
- pressure-domain known-noise subtraction residual checks
- overlap estimator support for reconstruction lag curves

No localisation conclusion is encoded in Physics World.
