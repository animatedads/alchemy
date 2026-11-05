# Native real-MP4 sample-map review — 5 November 2026

**Architecture:** Tom Dyer. **Media object code:** ChatGPT GPT-6. **Independent real-file qualification and review:** Claude (Opus 5.5), lane spash-3d-acoustic. From the supplied `review_ogg_mp4_20261105.zip`, `REVIEW_ogg_mp4_20261105.md`; this document records the reviewer measurements, **not a fresh test execution by ChatGPT**.

## Findings on PR #138

1. A missing `::requires 'MediaByteSource.cls'` in `MediaRangeCache.cls` caused `test_media_cache_1gb.rex` to fail at class-load time. The one-line fix (already committed `20a19433ee7ee7d6faf42d974c10b1db731e9491`) made the synthetic 1 GiB hot-jump/cache test pass at 16,384 bytes fetched.
2. Real TP08 MP4 (256 MiB) has **edit lists** on both tracks. The production `mapSamples` correctly refuses an unimplemented edit-list timeline. This is still an **incomplete implementation**, not an unimportant file anomaly.
3. Using a diagnostic **edit-list bypass only**, the raw MP4 sample-table mapping covered **all 63,524 A-law audio samples**, matching independently observed packet byte offsets and sizes. Presentation timestamps differed by a constant **8,010 ticks at 90 kHz = 89 ms**, attributable to the edit list. Reported sign: video time = original Ogg/audio time + 0.089 s for TP08. This observation does **not** qualify a production A/V join before `elst` is implemented.
4. Parsing the real audio sample map fetched 1,753,168 bytes (0.65% of the 256 MiB file), but took roughly **22 seconds of ooRexx CPU**. Persist an immutable source-version-bound sample/seek index rather than rebuilding it for each jump. Subsequent requests should fetch only required sample byte ranges plus constrained codec pre-roll.
5. Two older listening WAVs lacked source file, stream, channel and exact origin. Their envelope matches against the available original media were inconclusive (reported z=4–5). No audio label is attributable to an unknown-source derivative.

## What the accompanying diagnostic does

`review/real_mp4_20261105.rex` is the supplied reviewer script. It intentionally directly constructs `MediaMp4SampleTable` **without applying the edit list**, to independently inspect sample byte offsets and size. It is **NOT** a production decoder/seek path and **MUST NOT** be used to claim an A/V aligned timestamp or bypass the `mapSamples` production fence. Test input and packet reference must remain local. The script does not create audio or invoke ffmpeg; it writes a private numeric table.

## Next acceptance conditions

- Parse both `elst` version 0 and 1 (including empty edits and media-time offsets) and map media duration and track timescale to movie timescale without silently guessing offsets.
- Real TP08 63,524 audio samples retain exact offset/size and map presentation time with the observed 8,010-tick shift; test independently against a trusted packet reference.
- Cache the immutable index with source identity / size / version binding, and prove hot repeated seeks transfer bounded bytes and avoid the 22-second rebuild.
- Qualify video-track sample mapping and other real MP4 variants independently. No deployment or merge until those real edit-list tests pass.

Original media, private source hashes, PCM and user labels are not committed.
