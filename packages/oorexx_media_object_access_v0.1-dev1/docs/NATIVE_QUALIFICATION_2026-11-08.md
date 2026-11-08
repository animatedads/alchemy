# ooRexx Media Object Access dev3 — native qualification (8 November 2026)

## Provenance and authority

- Runtime: user-supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(2).deb`, extracted locally without system installation.
- Interpreter reported **ooRexx 5.3.0 r13196 Internal Test, 64-bit**.
- Application parsing, PSI/PES/PTS, index construction, serialization and seek planning executed in ooRexx; no Python/FFmpeg used in this qualification.
- Source basis: Library Media Object Access dev1 baseline plus dev3 source delta; this is **not** the entire PR #138 dev2 MP4 source tree.
- The three user-supplied `.mkv`-named recordings were identified by content as **188-byte MPEG-TS**, H.264 stream type 0x1B on PID 256, 90,000 ticks/second.

## Native test matrix

| Executed test | Evidence | Result |
| --- | --- | --- |
| `rexxc` MediaTsFile.cls | native syntax compilation | PASS |
| `rexxc` MediaFileProbe.cls | native syntax compilation | PASS |
| `rexxc` Mp4IndexSnapshot.cls | native syntax compilation only | PASS |
| `test_seek_index.rex` | binary integer tick lookup | PASS |
| `test_sparse_mp4.rex` | 1 GiB synthetic MP4 tail metadata, 32 source bytes | PASS |
| `test_ts_contract.rex` on streams 1/2/3 | signature, PSI/PMT, PID, H264, native IDR candidate extraction, sidecar round trip | PASS on 3/3 |
| `test_ts_hotseek_real.rex` on streams 1/2/3 | sidecar physically written, reopened, restored; 9 zero-I/O hot-planning checks and bounded TS packet probes each | PASS on 3/3 |
| Moonsault v0.1 `test_ephemeris.rex` | 6 external Sun/Moon reference cases, 24 angles, visibility and J2000 | PASS |

### Real recording results

| Stream | Bytes | IDR candidates | Sidecar bytes | First-time indexing read bytes | Reopen probe read bytes | Planning seek source bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| stream1 | 3,785,192 | 12 | 547 | 3,833,326 | 48,134 | **0** |
| stream2 | 6,036,680 | 12 | 549 | 6,084,814 | 48,134 | **0** |
| stream3 | 2,730,324 | 12 | 546 | 2,778,458 | 48,134 | **0** |

Each of the 27 hot-seek lookups used a saved sidecar to binary-search PTS and plan at most 65,536 bytes. Requested packet offsets were 188-byte aligned; direct 188-byte bounded reads at the selected offsets found `0x47` TS synchronization. The last extracted access point had PTS 5,076,000 ticks (56.4 seconds). IDR access points are **candidate anchors**, not certified random decoded frames.

### Native fixes discovered during qualification

1. Original TS test placed `::requires` before executable statements; moved these to the directive section. This was a real ooRexx 5.3 translation failure, not a media failure.
2. Strengthened disk-sidecar qualification to **truncate/rewrite** the manifest with `STREAM(...,'OPEN WRITE REPLACE')`; `CHAROUT` alone can leave a stale trailing byte when overwriting an existing index. The test now validates exact persisted length and byte-for-byte reread before restoring.
3. Added separate zero-source-read assertions for hot seek planning, and bounded physical 188-byte packet probes after planning.

## Remaining gaps / explicitly not claimed

- The test source identity is deliberately a local fixture key derived from filename and size. **Production cross-MU index re-use requires immutable Storage Fabric content/version identity and atomic sidecar publication.** Filename/size alone cannot protect a mutable source.
- A decoded H.264 frame was **not** produced. IDR and container markers are not a guarantee of exact presentation-time decode. Open GOP, B-frames, reference/preroll requirements and PTS ordering still need a qualified codec provider before `seekTime(EXACT)` can be enabled.
- MP4 dev2 edit-list/snapshot integration tests from PR #138 were **not run here** because this runtime workspace contains the dev1 Library archive plus dev3 delta, not the complete latest dev2 source. Only the legacy sparse-MP4 test and the new snapshot class' translation were exercised.
- No visual stellar detections or catalogue plate solve have been qualified natively from the three streams. The video pixel decoder/provider remains the next gate for Moonsault.

## Reproduce

Set `LD_LIBRARY_PATH` to the extracted ooRexx `usr/local/lib` and add its `usr/local/bin` to `PATH`. Run the test files from `tests/`, with `::requires` in the directive section:

```sh
rexx test_seek_index.rex
rexx test_sparse_mp4.rex
rexx test_ts_contract.rex /path/to/resident/stream1.mkv
rexx test_ts_hotseek_real.rex /path/to/resident/stream1.mkv /path/to/sidecar-dir
```

Full stdout, SHA-256s and test commands are preserved in `native_qualification_2026-11-08.log` in the deliverable. No user video footage or media bytes are included.