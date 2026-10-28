# Media Processing on Memory Fabric

Memory Fabric v0.1-dev10 is a strong fit for media because a media timeline is logically large while each method usually needs only bounded windows.

## Sparse logical media

A media source can be represented as an enormous logical ordinal space without making every frame/sample resident.  Source-backed ranges should normally be `REFERENCE` extents.  Derived buffers can be:

- `DATA` when resident;
- `SHARED` for immutable shared calibration/model material where the backing provider genuinely supports shared mapping;
- `RECONSTRUCTABLE` for disposable decode/flow/transform caches;
- `ZERO` where zero-fill is semantically exact;
- `HOLE` where no material exists.

`REFERENCE` does not mean the bytes have been copied into Memory Fabric.  It means the logical range has an external authoritative material reference.

## Adaptive event horizon

Sequential frame/sample consumers should open a Memory Fabric read cursor over the method's current read window.  The event horizon can be adapted from **observed** consumption rate and observed acquisition latency:

`ceil(rate × latency × safety factor)`

This gives the fabric advance notice before the consumer reaches the end of its resident window.  The media layer may observe the resulting demand; it must not counterfeit demand satisfaction.  Memory Fabric remains the movement authority.

This is especially useful for:

- decode → analysis pipelines;
- sliding optical-flow windows;
- long spectrogram/STFT passes;
- sequential ASR/phonetic analysis;
- temporal reconstruction sweeps;
- forward-model replay over the same source windows.

## Independent read horizons

Different methodologies may read the same logical source at very different rates and positions.  They should have independent cursors rather than forcing one giant common resident window.  Memory Fabric dev10 already coalesces overlapping resident islands without materialising logical gaps.

A slow blind-deconvolution branch can therefore coexist with a fast edge-measurement branch over the same source identity.

## Reconstruction and sparse backing

Reconstruction support is naturally sparse.  A leading-edge reconstruction may have well-supported strips separated by unresolved interior.  Sparse backing should preserve that distinction rather than allocate/fill unsupported regions.  A later synthetic inpainting method must use a separate reconstruction/material identity and cannot overwrite the source-supported support map.

