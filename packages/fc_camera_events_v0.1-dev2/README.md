# FC Camera Events v0.1-dev2

A single-file ooRexx worker for the fixed **FC / Front Castle** CCTV camera.

It analyses one local MP4 and records three evidence families on the **video
file's own decoded timeline**:

1. **traffic motion** in the FC road view, including the user-marked thin red
   sight line used by the older camera framing;
2. **window state** (`OPEN` / `CLOSED`) along the user-marked blue diagonal
   window edge;
3. **room reflection visible** evidence when the window is classified closed,
   including the strong night-time room reflection shown in the supplied
   reference image.

## Worker boundary

This package deliberately does **not** perform SSH, BashQueue submission,
corpus allocation, remote cleanup, or deletion of the delivered MP4. Codex and
BashQueue own those operations.

A worker receives one local file, writes evidence TSVs, returns a status code,
and leaves the input untouched. Cleanup can therefore be gated on rc=0 plus a
`.run.tsv` row with `status=OK`.

## Timing authority

`00:00:00.000` is the first decoded video frame of the supplied MP4.

Each sample uses:

`AVFrame.pts * AVStream.time_base`

with the first decoded PTS subtracted before any public timestamp is emitted.
Filename clock text, wall clock, audio edge corrections, `FILE_EDGE_MAP.tsv`,
and neighbouring files are deliberately irrelevant to event time.

A motion comparison spans the previous sampled-frame PTS through the current
sampled-frame PTS. Window/reflection intervals use the same sampled video PTS.
This gives every node the same file-relative coordinate system regardless of
which ED209 machine happens to process the shard.

## FC visual regions

All regions are expressed in normalized frame coordinates over the default
32x18 luminance grid rather than hard-coded 1920x1080 pixel rectangles.

### Traffic / red sight line

The thin road sight line annotated in red is explicitly represented by
`FCVehicleMotionConfig~trafficSlitCell`. It follows the diagonal road aperture
visible through the railings in the older FC framing.

The previous lower-road region remains available as well, because the camera
framing changed between recordings. `roadCell` is the union of the red sight
line and the later lower-road region. This means a change of framing does not
silently remove the original traffic aperture.

Every admitted traffic episode records whether it actually touched the red
sight-line mask (`SLIT_CONTACT`, `SLIT_SAMPLES`, `SLIT_SCORE`) in the unified
camera-event evidence.

### Window state / blue sight line

The blue annotation follows the diagonal window edge. The state probe samples
immediately inside that edge:

- when the window is **open**, that region exposes the dark interior gap;
- when the window is **closed**, the glass / reflected scene occupies it.

The classifier uses the probe mean divided by whole-frame mean, making the
decision substantially less sensitive to exposure changes:

- ratio <= 0.78 -> `OPEN`
- ratio >= 0.88 -> `CLOSED`
- between those values -> `UNKNOWN`

A state must persist for four sampled frames before an interval is emitted.
`UNKNOWN` is retained in `.scene.tsv` and is not forced into either state.

The supplied open-day and closed-night reference images were used to check the
geometry. Under the development crop used for qualification, their measured
probe ratios were approximately 0.54 (open) and 1.07 (closed).

### Closed-window room reflection

Reflection classification is intentionally gated by window state. Exterior
texture, wires, trees or clouds are **not** called a room reflection just
because they contain edges.

When the window is `CLOSED`, the analyser measures spatial edge density in the
upper glass/exterior field (excluding the FC OSD). A reflection episode is
admitted only when both edge strength and edge fraction pass the configured
thresholds for at least three sampled frames.

The output class is `ROOM_REFLECTION_VISIBLE`. It means visible structured
room reflection in the glass; it does not identify a person or infer activity
inside the room.

## Traffic-motion method

The traffic detector follows the direct Foreign Runtime / FFmpeg luminance
path established by Camera Behaviour v0.56:

1. decode H.264 through libavformat/libavcodec/libavutil;
2. sample luminance on a 32x18 grid every 8 decoded frames;
3. remove frame-global luminance before differencing;
4. examine only the FC road union mask described above;
5. form active motion samples from changed cells;
6. group temporally adjacent samples into episodes;
7. admit `CAR_MOTION` only when persistence, spatial travel, duration,
   strength and direction evidence jointly satisfy the gate.

The unified stream calls those admitted episodes `TRAFFIC_MOTION`.

This is **not** vehicle identity, licence-plate recognition, make/model
recognition, facial recognition, or person tracking.

## Outputs

For output prefix `/work/20231012_084716_tp00116`:

- `.camera_events.tsv` — merge-friendly stream containing
  `TRAFFIC_MOTION`, `WINDOW_OPEN`, `WINDOW_CLOSED`, and
  `ROOM_REFLECTION_VISIBLE`;
- `.events.tsv` — compatibility traffic/car-motion event detail;
- `.samples.tsv` — active road-motion comparison evidence;
- `.scene.tsv` — every sampled frame's window and reflection evidence;
- `.window.tsv` — persistent open/closed state intervals;
- `.reflections.tsv` — admitted room-reflection episodes;
- `.run.tsv` — decoder, timing, configuration and event counts.

All event times are file-relative milliseconds plus `HH:MM:SS.mmm`.

The input MP4 is never removed by this code.

## Invocation

Preferred entry point:

```sh
rexx tools/analyse_fc_camera_events.rex \
    /local/job/input.mp4 \
    /local/job/result/input
```

The previous `tools/analyse_fc_car_motion.rex` name is retained as a
compatibility entry point and produces the same seven outputs.

Exit codes:

- 0 — analysis and evidence writing completed;
- 2 — usage error;
- 3 — media analysis failed.

## Distributed use

No coordination is required between ED209A, ED209B, ED209D and ED209I. Each
job is semantically independent:

`one MP4 -> one file-relative event bundle`

BashQueue completion order does not affect timestamps or classification. A
coordinator can concatenate/merge the per-file evidence later using
`source_file` plus file-relative time.

## Qualified dependency pins

- ooRexx 5.3.0 r13196
- ooRexx Foreign Runtime v0.22.6
- Camera Behaviour ooRexx v0.56 design/provenance boundary
- FFmpeg ABI descriptors copied byte-for-byte from Camera Behaviour v0.56
