# Physical drum kit — v0.1-dev46

`DrumKitPhysics.cls` is a peer instrument to the existing guitar mechanics, not a guitar subcomponent and not a sample player.

The `standardRockKit` factory creates nine independently positioned voices: 22-inch kick, 14-inch snare with deterministic snare-wire modes, 10/12-inch rack toms, 16-inch floor tom, 14-inch hi-hat, 16/18-inch crashes and a 20-inch ride. Each voice carries physical reduced-order head/shell/plate modes with effective mass, natural frequency, damping, displacement, velocity, radiating area and mechanical energy.

Strikes apply impulses to the physical modes. `step()` advances those modes. Hi-hat openness changes contact damping and cymbals can be choked. External acoustic pressure can excite every voice, so an unplayed drum or cymbal is not artificially silent when the guitar amplifier, monitors, or other instruments drive the room.

The kit retains bounded volume-acceleration history. `pressureAt()` uses retarded emission time, the Physics acoustic medium, distance attenuation and current surface transmission to produce a `DrumPressureObservation`; this is suitable for sharing the same room/acoustic solver used by the guitar without merging the two instrument classes.

`attachToWorld()` registers `DrumKitFreezeParticipant` under schema `physics.drum-kit-state/0.1`. `PhysicalWorld~freeze/restore` therefore captures and restores modal state, hi-hat state, kit time and acoustic history coherently with the guitar and other Physics participants.

This is a physically parameterised reduced-order kit, not yet a finite-element membrane/shell/plate solver. The modal data are development defaults and are explicit rather than being presented as measurements of a particular commercial drum set.


## dev46.1 structural coupling

The standard rock kit now publishes weak reciprocal `DrumStructuralLink` spring/damper connections between representative support/shell/plate modes. These links model stand/rack/floor mechanical transmission at reduced order: equal-and-opposite generalized forces are applied during the same symplectic-Euler step and link spring energy is included in `totalMechanicalEnergy`. This is intentionally separate from acoustic-pressure coupling through the room.

`DrumModalMode` caches invariant angular frequency, stiffness and damping coefficients and keeps the current acceleration as state-derived observation cache. Damping changes (for example hi-hat openness/choke) refresh the cached coefficient.

Acoustic history is a FIFO `Queue`, not a sparsely-indexed `Array`; pruning with `pull` preserves contiguous indexing required by interpolation and freeze/restore.

### Fixed-listener real-time observation
For a known fixed microphone position, `DrumFixedMicStream` may be used with `stepWithoutHistory()` to avoid allocating the general acoustic-history graph at audio rate. It advances the same live modal kit and applies the same per-voice compact-radiator acoustic gain and propagation delay using short causal fractional-delay buffers. The general history route remains authoritative for retrospective arbitrary-time queries.
