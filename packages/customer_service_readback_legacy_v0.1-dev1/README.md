# Customer-service readback: legacy recovery v0.1-dev1

Additive candidate, separate from the accepted controlled readback capture dev2 and the Video Mesh service.

Given the existing A02 audio-preparation manifest and readback vocabulary, produce 83 SHA-pinned recovery work definitions for 26 letters, 26 NATO entries and 31 number-named clips. A filename is an unverified hint, **not** what the video is known to say. A number filename is not translated into assumed speech.

The review function consumes independent word-timestamp transcripts of the existing schema, refuses missing source/audio hashes and mismatched clip identifiers, and returns only bounded review candidates. A word surrounded by improvised dialogue is marked contaminated. No generated results are approved as audiovisual assets.

Use the authoritative Storage Fabric, Migratable Job and Job-to-Node systems for actual placement and checkpointing. This package defines work only; it does not dispatch, fetch videos or call a paid ASR endpoint. No human or face identity inference.

Test: `python3 -m unittest discover -s tests -v`.

Plan: `python3 src/legacy_recovery.py plan --prepared /path/to/A02_prepared_manifest.json --vocab examples/readback_vocabulary.json --output A02_legacy_plan.json`.

Review: `python3 src/legacy_recovery.py review --plan A02_legacy_plan.json --clip NATO_A --transcript independent_NATO_A.json --output review.json`.

All tests use synthetic transcripts. A02 job counts were checked independently against the source preparation manifest. No live ASR, MediaPipe or mesh jobs have been executed.
