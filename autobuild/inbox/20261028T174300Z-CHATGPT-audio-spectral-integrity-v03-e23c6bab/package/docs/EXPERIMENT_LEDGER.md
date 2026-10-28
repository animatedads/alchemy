# 2026-10-17 to 2026-10-19 experimental continuity (documentation only)

Private source: two joined stereo phone videos (~181.95 s), one full-band joined audio file, one amplified low-pass derived view, and a ~30 s edited/amplified montage. **None redistributed.** Field descriptions, phrases and third-party source locations remain hypotheses not findings.

| Research step | Experiment status | Caveat |
| --- | --- | --- |
| 4 kHz low/high listening split | Explored | High-pass regenerated from full-band source; boosted material not an independent source |
| 0–1.5 kHz plus >4 kHz combination | Explored | Different filter response may shift perceptual salience |
| Twelve-band 0–22 kHz two-pass sweep | Explored | Heuristic speech-shaped metrics not speaker/source classifiers |
| 600–1000 vs 1000–4000 stereo | Explored | Shared modulation can arise from common noise and mixing |
| 200 Hz envelope/harmonic plots | Explored | Narrow-band autocorrelation f0 is often circular; use external f0 |
| Two TTS utterances in alternating 100 Hz slots | Synthetic positive demonstration | Feasible without proving field occurrence |
| Final 20s alternating odd/even 100 Hz views, 12/24 dB preference | Explored | Pure spectral rearrangement never proves second recording |

**New reproducibility increment:** `src/spectral_integrity.py` + numerical regression tests. Source media, TTS audio and output FLACs are deliberately external to this public package. Tests use fully synthetic waves.

Outstanding: verified near-voice control timestamp, video contact-event alignments, robust pitch/inharmonicity tracking, null-model suite with natural overlap and codec/wind controls, blind independent listening protocol, and Gopher full qualification on current runtime. No field causation or attribution claim is made.

## 2026-10-27 v0.2 bounded increment

Shifted odd/even bucket origins (0/25/50/75 Hz) plus known synthetic A/B
interleave added as falsification/reference controls. Synthetic tests PASS on
Python/NumPy locally. Field audio remains private; any derived listening views
remain exploratory, and the quoted language and alleged origin are unresolved.
For any speaker/source/intent claim, require externally validated provenance,
blind text recovery and independent null rejection. The private-field report is retained only with private derived outputs, not
in the public source-control submission.

## 2026-10-28 v0.3

Added WOLA locally windowed bucket views alongside full-clip FFT, one-source-notched/ordinary-overlap/engineered-weave control suite, oracle template projection requiring both exact source references, and a four-condition blinded playback generator with private unblinding key. Synthetic regression PASS; private field attribution unexamined, Gopher activation and Autobuild acceptance not yet claimed.
