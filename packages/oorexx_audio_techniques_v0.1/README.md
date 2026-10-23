# ooRexx Audio Techniques v0.1 — executable reference increment

Pure ooRexx implementation of seven foundational time-domain processing techniques with one swappable registry: DC removal, pre-emphasis, de-emphasis, causal moving average, centred median filtering, sample-wise energy gate, first difference.

This is an **additive**, **limited** implementation, not a claim that the comprehensive audio methodology catalogue is implemented. These are time-domain operations, not Log-MMSE, Martin minimum statistics, beamforming or neural enhancement. The gate is sample-wise, not a speech activity detector. Filters are block-local and do not yet retain state across blocks. `AudioTechniqueRegistry~register` allows additional technique objects. The API uses `.Array` PCM samples and a numeric parameter.

Run on ooRexx 5.3.0 r13196:

```
cd oorexx_audio_techniques_v0.1
rexx tests/smoke.rex
```

Validation: PASS under the user-supplied ooRexx 5.3.0 r13196 Ubuntu debug package, extracted to an isolated directory; no system-wide installation. No source media were processed.

Next work: match existing Maths provider/precision APIs; add stateful DSP, spectral methods, qualification corpus and catalogue method statuses. Do not conflate this reference implementation with existing accelerated Maths functionality.
