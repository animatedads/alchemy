# FFmpeg / Foreign Runtime boundary - Layered Audio v0.16

The native FFmpeg provider remains the v0.15 typed-structure implementation for container/audio decode and v0.12+ PCM transform/resample.

v0.16 does not change the decoder ABI contract. It requalifies it under Foreign Runtime v0.22.2 and then layers ML material/tensor binding on top of the decoded PCM result.

The camera tensor-material regression uses the bounded mono `fltp` result from `1000053605.mp4`. Because Runtime Reference PURE results are value objects, the decoded Rexx byte string is explicitly copied once into a managed ForeignBuffer before zero-copy NumPy/ForeignTensor sharing begins.

No FFmpeg CLI subprocess or FFmpeg-specific C shim is used.
