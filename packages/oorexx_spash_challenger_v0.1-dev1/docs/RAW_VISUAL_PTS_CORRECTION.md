# SPASH challenger: raw TP8 visual timing correction

Date: 31 October 2026. Architecture: Tom Dyer. Frame-rate discrepancy identified by Claude. Native implementation and validation: ChatGPT GPT-6.

## Primary measurement authority

Use the original FD_DOOR_MICRO_SAMPLE_V2 TSV together with FD_DOOR_MICRO_RUN_V2, rather than the 149 grouped event summaries. The run receipt states time_base_num=1, time_base_den=90000, STEP=1, decoded frames=90748, samples emitted=90726, geometry epochs=1, relocations=0, last_relative_ms=6352263.

The uploaded complete TP8 raw series includes 90,726 observations from decoded-frame ordinals 23 to 90,748. Across 90,725 consecutive raw observations, intervals average 69.99948 milliseconds, i.e. 14.28582 observations per second. 74,880 differences were within 3ms of 60ms, 15,038 were within 3ms of 120ms, and 807 had other differences. This cadence is not uniform.

Important terminology: the raw sample field is a video-frame ordinal in this STEP=1 run, but the ordinal is NOT a timebase. Using ordinal multiplied by 60ms makes the final TP8 time approximately 907,383ms (15m07s) too early. Do not replace the mistake with a blanket 70ms multiplier: the actual PTS is authoritative, including irregular gaps.

PTS at the last raw sample is 571703629, and its exact video-relative time is 571703629*1000/90000 = 6352262.544ms, consistent with the reported rounded 6352263ms.

## Correct projection and window aggregation

Video time is raw_pts * time_base_num / time_base_den. Each source motion row describes a displacement step between two observed video PTS instants. For a query window [A,B), intersect each [pts[i-1],pts[i]] with [A,B), prorate its displacement by the overlapping PTS duration fraction, sum components and divide by ACTUAL COVERED seconds. Keep signed global dx/dy, door left/right residual and absolute global/door magnitudes separate. The source motion is visual pixel displacement, not a microphone pressure signal, event name or physical source localisation.

Geometry epoch changes and unstable frame states cannot be silently merged. Returned observation authority is RAW_PTS_STEP_DISPLACEMENT. Audio clock remains NOT_ALIGNED.

Existing visual mechanical events are secondary index hints. Their PTS-derived timestamps might still be correct, but 149 grouped events are not an adequate substitute for 90,726 raw time-tagged movement vectors; neither 362 nor 426 aggregated event tables is a primary motion series.

## Audio clock and SPASH integration

An independently observed cross-clock mapping must exist before declaring a video movement synchronous with original FC or FD audio. The model needs an audio_offset, rate/drift and uncertainty from real calibration: audio_sample = audio_sample_rate * (alpha * video_pts_seconds + beta). Filename dates or invented frame-rate offsets are not enough.

Treat these raw PTS movement windows as additional candidate timing priors for the independent SPASH challenger. They are not automatic speech labels, siren/klaxon identities, or evidence that a virtual microphone physically captured audio. Run alternative window sizes and strategies over the same PTS source, using Storage Fabric identities for original and derived layers. Maintain held-out negative controls and do not delete overlapping possible speech when excluding a tonal alarm.

## Executed qualification

ooRexx 5.3.0 r13196 internal test: 24 positive cases and six fail-closed PTS/source/run mismatches PASS. Complete original TP8 raw metadata processed in native ooRexx: 90,726 samples, 6,350 one-second windows, 22 seconds, about 340 MiB peak RSS. Current implementation is an in-memory indexed prototype; a resumable Storage Fabric streaming cursor and 10-MU orchestration remain unfinished. No audio processing was undertaken here; acoustic DSP belongs to the existing Audio V9 / Layered Audio / Maths / Physics owners. Do not promote this work to 3D source localisation or a POI1 match.
