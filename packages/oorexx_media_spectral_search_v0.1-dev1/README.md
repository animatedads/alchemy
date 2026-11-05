# ooRexx Media Spectral Search v0.1-dev1

An initial, source-neutral time-frequency material and search interface. ooRexx selects the source, track, channel, exact bounded window, and reversible spectrum-gain rules. SPASH native Ogg seek is a replaceable decoder beneath that interface. A small C provider performs FFT arithmetic and writes every frame/bin value; the ooRexx map object retains time, frequency, source Nyquist and source identity.

```rexx
media=.MediaOggFile~new(sourcePath,sourceSha256,seekBridge,privateCataloguePath)
search=.MediaSearch~new(spectrumBridge,privateOutputDirectory,2048,512)
search~setSpectrum(100,2000,10)
search~setSpectrum(2001,20000,0)
map=search~process(media~seek(100000,110000,1,0))
say map~rawDb(0,42) map~weightedDb(0,42)
```

`process` writes decoded float32 PCM, a decoder receipt, a row-major float32 dense spectrum, an FFT receipt and an ooRexx manifest into the caller's private output directory. It never writes to the source path. The current Ogg decoder request is limited to 120 seconds and 64 MiB compressed bytes. A caller can retain overlapping tiles to cover longer recordings without using voice activity as an admission gate. `processCoarse` creates a one-second power average as a derived view; the dense map is primary.

The built-in sample-rate policy preserves 8/16 kHz source rates and uses 48 kHz for higher-rate sources. Bins above the **original** Nyquist are `OUT_OF_SOURCE_BAND`, even when resampling creates numeric values there. `setSpectrum` changes only a view; it does not delete or rewrite raw values. `bandProfile` calculates a reproducible time-variation summary by reading every dense frame/bin in each named band. It is a signal measurement, not a speech detector or transcription.

## Build and qualification

On Linux, compile `media_spectrum_fft.c` with `cc -O2 -std=c11 -Wall -Wextra -Werror -fPIC -shared -lm` to `libmedia_spectrum.so` alongside the bridge. The package depends on ooRexx 5.x, Foreign Runtime v0.22.6, and the SPASH native Ogg seek package. `tests/run.sh` builds the provider and checks 1 kHz, 0.5-amplitude synthetic sine input: the measured peak must be within 0.1 dB of −6.0206 dBFS, the +10 dB view must add exactly 10 dB, and frame/bin counts must match. The test requires `FOREIGN_RUNTIME_LIB_DIR` and `FOREIGN_REXX_DIR` environment variables; no media archive is needed.

The bundled SPASH dependency is still under qualification. Its v0.2 source at commit `05c0af2504fd8eee5bac90fc8b3d095e18c5c512` has known limitations around some Vorbis PTS discontinuities, simultaneous synchronized multitrack output, chained Ogg, and persistent seek/index state. This component does not silently repair those cases. It does not provide MP4 sample-table navigation or infer clock alignment between recordings. Decoding and mapping failures are surfaced to the caller.

No recordings, coordinates, speech labels, or private case data are part of this package.
