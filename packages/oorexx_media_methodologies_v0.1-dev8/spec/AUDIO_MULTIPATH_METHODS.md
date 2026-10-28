# Audio multipath methodology family

Dev5 adds five explicit methodologies learned from the qualified Audio V9 line rather than forcing those techniques into generic echo-cancellation, beamforming, or room-response labels.

## Sparse coherent path estimation

`AUDIO.MULTIPATH.PATH_ESTIMATE` measures delayed coherent copies of a directly observed event. Delay is **excess path timing**, not source range. A useful path is an observation about the received acoustic field under the estimator's assumptions; it is not a solved reflector geometry.

## Time-varying spectral path tracking

`AUDIO.MULTIPATH.SPECTRAL_TRACK` associates paths through time using both delay continuity and source-relative spectral-transfer compatibility. Low/mid/high transfer, per-band coherence and transfer stability remain measurements. Spectral transfer is not source identity, and delay-rate is not reflector velocity.

## Motion-induced path coherence

`AUDIO.MULTIPATH.MOTION_COHERENCE` combines already-measured delay, Doppler/time-warp, spectral-transfer, reconstruction and physics compatibility. The Candidate18 continuation is methodologically important: one final delay/time observation must cross a shard boundary so the first derivative in the next block is not silently lost. This is processing continuity, not source evidence authority.

A video-visible motion interval may be carried as context, but it contributes **zero direct acoustic score**. This prevents a visual event from manufacturing acoustic coherence.

## Physics compatibility

`AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY` expresses excess path length and excess-path-length rate using a declared propagation model, then scores bounded causality, motion plausibility and transfer stability. It deliberately produces neither source-range probability nor reflector velocity.

## Multipath virtual microphone reconstruction

`AUDIO.RECON.MULTIPATH_VIRTUAL_MIC` is a reconstruction method. Stable coherent reflected paths become delay-corrected secondary observations and are combined conservatively with the direct signal. The evidence branch is non-amplifying. A listening branch may exist elsewhere, but listening gain is not evidential recovery.

The reconstruction and the path estimator share a foundation. Therefore a reconstruction agreeing with the path estimator is **not independent corroboration**. The provider result records this dependency explicitly.

## Applicability and negative controls

A request does not force a reconstruction. If the selected event has no useful coherent path support, the reference provider returns `NOT_APPLICABLE / NO_USEFUL_COHERENT_PATH`.

Dev5 qualification includes both a strong speech-energy event in TP00001 and a low-energy control from the same ten-second source interval. The former exposes multiple useful coherent paths; the latter fails closed.
