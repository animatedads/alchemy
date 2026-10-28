# Controlled Audio V9 provider qualification

The controlled fixture uses a deterministic broadband transient at 8 kHz with injected delayed copies at 15 ms (+0.55), 42 ms (-0.32) and 78 ms (+0.18), plus low background noise.

The sparse path provider recovers useful paths at exactly 15 ms and 42 ms. The 78 ms path is deliberately weak and is not required by the qualification gate. The virtual-microphone provider returns a derived candidate.

Upstream Candidate18 regressions are also run for:

- measured multipath + non-amplifying/amped reconstruction;
- spectrally aware multipath trajectory tracking;
- motion-induced delay/Doppler/reconstruction coherence;
- split-block continuation equivalence to whole-window processing.

The shipped Candidate18 `test_audio_v9_coherence_continuation.rex` places `::requires` directives before executable code and fails translation on ooRexx 5.3.0 r13196. Media Methodologies does not modify that upstream package. A qualification-only harness with the directives moved to the normal directive section executes the same object-contract assertions and passes under r13196.
