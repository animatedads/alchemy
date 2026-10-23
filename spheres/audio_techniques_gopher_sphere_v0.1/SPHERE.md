# Audio Techniques and Forensic Processing — Alchemy Sphere v0.1

## Authority and scope
This is the documentation sphere for the additive ooRexx Audio Techniques effort. It records architectural decisions, executable implementation inventory, technique gaps, dependency boundaries, qualification and publication status. It is not an authority to modify the Audio V9 search engine, Layered Audio, Media Methodologies, Maths, or evidence originals.

## Source provenance
- User Library `METHOD_INDEX.md`: Media Methodology Index, 170-method baseline; AUDIO categories include acquisition, analysis, calibration, forensic, measurement, reconstruction, restoration, semantic analysis, separation, spatial and system identification. Catalogue is open-world. This sphere does not supersede its IDs or maturity classifications.
- User Library `PA-STK-MEDIA_Audio_and_Media.pdf`: NotNotes v0.4 media stack identifies Audio V9 Pattern Locator, Audio Rexx Search, Layered Audio v0.22-dev2, Speech, and media dependencies. Its inventory is a historical snapshot, not a current source revision authority.
- GitHub `packages/oorexx_maths/README.md`: Maths v0.17, reference/PURE semantics, precision and proof policy; accelerated providers are optional, and binary64 conversions must be explicit.
- GitHub `packages/oorexx_maths/DISCRETE_STATE_SPACE.md`: checkpointable recurrence, sample-time convention, and workload-aware PURE/NUMPY selection.
- GitHub `GIT_SUBMISSION.md` and `MANAGED_ZIP.md`: immutable Autobuild Git intake and integration schema 0.2.

## Implementation inventory (as submitted, not accepted)
| Submission | Classes or techniques | Status |
|---|---|---|
| v0.1 `20261016T223000Z-CHATGPT-oorexx-audio-techniques-v01-a71c9d` | DC removal, pre/de-emphasis, moving average, median, sample energy gate, first difference | Git submitted; receipt not verified |
| v0.2 `20261023T144500Z-CHATGPT-audio-models-v02-c4a672` | NLMS, positive spectral flux, zero crossing | Git submitted; acceptance not verified |
| v0.4 `20261023T144300Z-CHATGPT-audio-spectral-v04-b8e51f` | noise-only EWMA, Wiener gain, spectral subtraction gain, decision-directed a priori SNR | Git submitted; acceptance not verified |

The v0.4 package includes the v0.3 family. These are reference-level partial operators, not an end-to-end PCM enhancement chain. Earlier assistant reports of local runtime PASS are not a substitute for independent Autobuild acceptance receipts. No claim is made that the current sphere package executes the algorithms itself.

## Semantic boundaries
1. Audio owns technique semantics, parameters, method identity, applicability and evidence.
2. Maths owns FFT/convolution/matrix execution, numeric contexts, provider selection and numerical provenance; do not fork its provider system.
3. Media Methodologies owns method identifiers and maturity/experimental/reconstructive classification; catalogue entries do not imply implementations.
4. Layered Audio owns derivative-media lineage; originals are immutable, and all enhancements must be labelled derived.
5. Audio V9 and Audio Rexx Search own their existing evidence search and matching contracts; processing must not silently change reference signals.
6. Compute Layer / Job-to-Node / Migratable Job / Storage Fabric own portable execution, admission, checkpoint leases, pinned input and durable output. Never embed machine-local paths in portable technique definitions.
7. Speech hypotheses (ASR, diarization) are not evidence of actual words unless separately corroborated.

## Technique worklist (not implemented here)
- Maths FFT/STFT and inverse overlap-add, window normalization, sample-time preservation and multichannel phase.
- Proper MMSE-STSA and Log-MMSE, noise uncertainty tracking (MCRA, minimum statistics), OM-LSA, stateful filters and calibration.
- WPE dereverberation, beamforming DAS/MVDR/GEV, GCC-PHAT and room-response inference.
- Wavelet, NMF/ICA, sparse/Bayesian, modulation-domain, deconvolution and adaptive echo cancellation.
- Experimental generative enhancement and bandwidth extension only with clear reconstructed/hypothesized provenance and falsification tests.
- Provider equivalence, edge cases, synthetic ground truth, corpus-based failure cases and performance crossovers.

## Acceptance and safety gates
A technique is **DOCUMENTED** when described with provenance; **IMPLEMENTED** when source exists; **TESTED** only after tests run with recorded runtime; **QUALIFIED** only with numerical/reference comparison and declared limitations; **ACCEPTED** only with Autobuild receipt. Never equate maturity in the Methodology catalogue with implementation maturity.

Every executable technique must specify input domain (PCM, magnitude, power, complex spectrum), sample rate, window/hop, units, phase handling, precision, provider, state snapshot, failure modes and immutable source identity. Reject invalid inputs rather than silently invent missing signal evidence.

## Follow-up
Reconcile the three submissions against Autobuild receipts, fix any failures as new immutable submissions, then build an executable Maths-backed spectral pipeline and qualify each technique independently. Expand catalogue coverage by method ID, including experimental families, without misrepresenting their maturity.
