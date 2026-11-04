# Sydney Harbour V5V v0.28 — cruise ship, 2 November 2026

Architecture: user. Executed by GPT-6 from the three user-uploaded 60-second source video files, using the previously qualified Vision dev22-compatible native five-bit V5V surface/temporal encoder (source in v0.26).

## Physical evidence

A substantial, white multi-deck cruise ship is clearly visible in Stream 2 (Bridge-right / Opera House view, 1280×720) and Stream 3 (Café Sydney / Customs House view, 640×360). Similar vessel shape and nominally concurrent captures support a **same-ship hypothesis**. Stream 1 (Bridge-left, 1280×720) does not independently provide a clear same-vessel observation in inspected source frames.

The official Royal Caribbean itinerary and public port schedule put **Anthem of the Seas** at Sydney Overseas Passenger Terminal on 2 November 2026, scheduled to sail at approximately 17:00 AEDT. Camera 2's visible source overlay at around clip +30s reads 16:54:49. **SCHEDULE_MATCH_PROBABLE**, **OUTBOUND_SCHEDULE_COMPATIBLE**; not AIS-confirmed and readable ship markings are not established. Public references: https://www.royalcaribbean.com/itinerary/9-night-south-pacific-cruise-from-sydney-on-anthem-AN09K169?groupId=AN09SYD-3268217720&packageCode=AN09K169&sailDate=2026-11-02 and https://cruiseagency.com.au/sydney-cruise-ship-schedule .

## Actually executed V5V evidence

| Stream | Original video SHA-256 | 30fps frames | Keyframes / Deltas | Packed V5V bytes | Frames with zero changed indexed cells |
| --- | --- | --- | --- | ---: | ---: |
| 1 | `a58e8dccd63dba3cb12b5cad2dbfb50e6f2b8c5c7c03ebe3ffab181a6be2e202` | 1,800 | 60 / 1,740 | 921,427 | 614 |
| 2 | `6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830` | 1,800 | 60 / 1,740 | 921,907 | 388 |
| 3 | `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e` | 1,800 | 60 / 1,740 | 924,929 | 1,569 |

Native encode/decode **5,400/5,400 indexed-surface round-trips exact**, preserving original 1.400000…61.366667-second frame PTS, source identity and per-camera temporal edges. No OpenCV tracking, no inferred vessel identity, no geo-position. Stream 3 has *87% unchanged consecutive frames* at this coarse five-bit resolution, despite an enormous visible ship. This **supports long N-frame predictions** instead of treating an immediately unchanged frame as a lost object.

Conservative v0.26 motion-search bitmaps were reused for Streams 1/2 only as provisional diagnostic masks; Stream 3 uses a new **provisional** hand-shaped mask with 1,022 admitted V5V water-region cells. Water-mask statistics are not a qualified vessel detector. The whole 80×45 scene is stored irrespective of the movement masks.

At original frame index 900, the 2 **manually reviewed** source-resolution cruise-ship ROI crops have verified RGB24 hashes (extracted by *sequential* FFmpeg frame filtering to avoid MPEG-TS seek ambiguity):
- Stream 2: x365 y365 w150 h134; `e2738640ae7891690b60f554030112f15506fa3dff7be513de6d93a80edc2933`.
- Stream 3: x225 y95 w320 h184; `60e67bfd0428eb18030cdbafe0f0d9cb3d4c7179b22b1bb25034f34595cc129a`.

These rectangles are **manual source-linked observations**, not fully automated codec-generated predicted AOIs. Both source views and recovered V5V surfaces were visually reviewed. Every evidence record remains `OBSERVED_UNTESTED`; no canonical SLAM TESTED graph, no Power SLAM admitted real-world viewing ray, no surveyed pose, no confirmed ship identity.

Full reproducibility package in conversation: `sydney_cruise_ship_v5v_three_camera_v0.28.zip`, SHA256 `0daa2e12b898f8120a9d3b02e663f68315a1862fb4754bed52937d4fd82d163d`. Contains original-source SHA IDs, full V5B/PSV/PTS evidence for all 5,400 frames, native C provider source and palette, motion masks, exact RGB crops and digests, diagnostics and file integrity manifest. Original videos are **not redistributed**.

Next step: N-frame V5V tripwire and predictive tracking tuned for large slow-moving ships, second-pass appearance comparison using the two exact ROI crops, then pass those observations to Power SLAM with strict pose/uncertainty barriers. No code-path TESTED authority changes.
