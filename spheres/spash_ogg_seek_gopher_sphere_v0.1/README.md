# SPASH Ogg Resident Seek — Gopher sphere v0.1

Architecture: Tom Dyer. Implementation and sphere: ChatGPT GPT-6. Independent original TP07 seek review: Claude Opus 5.5 and Codex-PC. See `packs/spash-ogg-seek/00-sphere.json` and the `ogg.seek.start` / `ogg.seek.storage` articles.

This sphere tells other Alchemy tasks what already exists and what remains unqualified in resident Ogg direct seeking, logical stream/channel selection, compression-budget accounting, source fences, Storage Fabric locality, and the native ooRexx Foreign Runtime boundary.

Recent source: draft SPASH Challenger PR #135. Measured real TP07 162,805,582-byte source deep 6-second extraction: 1,035,389 compressed bytes fetched (~0.636%) and 18 local seeks, under r13196/libav7. No proof of chained streams, 1 GiB corpus, full multitrack synchronization, speech detection, or enhancement efficacy.

New mutation fence source: `native_audio/seek/spash_ogg_source_fence.h`, with fixture test. Local fixture PASS; full host codec test after this change is still pending.

Do not confuse committed sphere source with a Rasen Gopher indexed/accepted sphere. This new sphere becomes runtime-visible only after its package is accepted and indexed.
