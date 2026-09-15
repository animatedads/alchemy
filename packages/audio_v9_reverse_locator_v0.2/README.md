# Audio V9 Reverse Locator v0.2

Standalone companion utility for locating the historical `fcpaphos_project_v9_snippets` event WAVs back into the canonical 2023-10-09 / 2023-10-10 FC and FD original Ogg recordings on ed209i.

This package is deliberately separate from Audio Rexx Search. It does **not** alter the pure ooRexx/native A/B/C/D/E/I/H search package.

## Production layout on ed209i

```text
~/fcpaphos_project_v9_snippets/
  single_feed/     89 mono WAVs, 441,044 bytes each
  dual_feed/      582 stereo WAVs, 882,044 bytes each

~/fcpaphos_originals/20231009_20231010/
  camera_fc/
  camera_fd/
```

The original corpus must contain exactly 120 canonical files matching:

```text
YYYYMMDD_HHMMSS_tpNNNNN_original.ogg
```

Only dates `20231009` and `20231010` are admitted. Duplicate-date prefixes and long numeric-ID filename variants are rejected.

## Why the matcher tolerates V9 / amp32 differences

The snippets came from the V9 `amp32` domain and may be much louder, clipped or otherwise visually unlike the originals. The locator therefore does not use absolute waveform amplitude as identity. It indexes relative spectral landmark constellations: frequency/time pattern survives large gain changes much better than sample equality.

Stereo snippets are treated as two independent channels and a joint result is admitted only when the channels resolve to FC + FD at the same wall-clock time. Mono snippets search FC and FD independently.

## Sequential evidence

V9 assigned `evt_NNNNNN` in scan-time order, but classification generated snippets in descending `z_rms` order. Event number—not filesystem mtime—is the chronological key.

The supplied historical evidence proves three surviving classification batches:

- `gen1_legacy`: 71 snippets
- `gen2_legacy`: 300 snippets
- `gen3_current801`: 300 snippets

The current surviving event file contains 801 chronological events. If the first 371 historical snippet IDs are treated as already classified, V9's exact rule `pending -> z_rms descending -> max_ai_events=300` reproduces all 300 `gen3_current801` IDs with zero mismatch. Only that final generation uses old V9 timestamp/source metadata as a seed. All 671 are still acoustically verified against the canonical originals.

## Run on ed209i

Extract this package anywhere under the ed209i account. To emit the 300 surviving-current-scan metadata seeds first, without building the acoustic index:

```bash
./run_v9_locator_ed209i.sh --seed-only
```

Then run the complete acoustic verification/recovery:

```bash
./run_v9_locator_ed209i.sh
```

`--index-only` is also available when you want to build/rebuild the reusable source index separately.

### v0.2 index change

v0.1 stored about 17 million landmark postings in SQLite and then built a global B-tree with `CREATE INDEX postings_hash`, which dominated the first production run on ed209i after all 120 originals had already been decoded/fingerprinted. v0.2 replaces that with a direct 18-bit hash-space CSR index: `offsets.npy` maps each fingerprint hash directly to packed `source_ids.npy` + `frames.npy` postings. There is no global SQL index-build phase.

If the existing v0.1 package has already populated `~/audio_v9_reverse_locator_v0.1/run/v9_locator/v9_originals_landmarks.sqlite`, v0.2 can reuse those committed postings without decoding the 120 originals again. The ed209i driver looks for that sibling v0.1 path automatically (and also accepts `V9_LOCATOR_V1_SQLITE` as an override). Stop/finish the old writer first, then run:

```bash
./run_v9_locator_ed209i.sh --salvage-v1
```

That performs two sequential scans of the old postings table and writes the v0.2 CSR index.

It fails closed unless it sees the expected 671/120 corpus and FC/FD directory shape. Results are written under:

```text
run/v9_locator/inventory.json
run/v9_locator/gen3_metadata_seeds.tsv
run/v9_locator/v9_originals_landmarks.v9idx
run/v9_locator/locations.tsv
run/v9_locator/locations.jsonl
```

The CSR source index is reusable and records the same fail-closed source identity (basename, FC/FD family, size and nanosecond mtime). Set `V9_REBUILD_INDEX=1` only after the original corpus changes. A v0.1 SQLite file may remain beside it solely as salvage input.

## Requirements

- Python 3
- numpy
- ffmpeg
- ffprobe

No network service is required by the locator itself.

## Optional amplified review extract

After a locator run, render an 18-second +32 dB limited listening window around one chosen result:

```bash
./render_v9_review.sh evt_000347
```

For a stereo V9 event this produces separate FC and FD review WAVs. This is human review material only; the locator score itself is computed from the un-normalized canonical source patterns and does not depend on the review amplification.
