# Real CCTV media fixtures used for v0.45 acceptance

These files are external acceptance fixtures and are not redistributed in the Camera package.

1000053572.mp4  sha256=7298322bcbda70d745d14ba7fc2b1c4ff6d3bdda04602ae3c14f5e8e6dd4cbea  bytes=2742560
1000053573.mp4  sha256=fc658229e170cfea6534c57b0a124901fb0a316db183a811004096812ff66c2f  bytes=2186306
1000053574.mp4  sha256=037e47ee618bb0ec2f888172ae5a174f2c8275ac2dc6c854aac30035502ad8d8  bytes=1653991

Direct v0.46 libavformat/libavcodec packet-demux acceptance (FFmpeg libavcodec 61.19.101):

1000053572.mp4  packet_count=1837  terminal_status=-541478725
1000053573.mp4  packet_count=1837  terminal_status=-541478725
1000053574.mp4  packet_count=1837  terminal_status=-541478725

`-541478725` is FFmpeg EOF on the qualified ABI. Counts are evidence for these exact fixtures, not a format-wide invariant.

Direct v0.47 frame decode acceptance (Foreign Runtime v0.11.1, FFmpeg libavcodec 61.19.101 / libavutil 59.39.100):

1000053572.mp4  video_packets=900  decoded_frames=900  geometry=640x360  pixel_format=0  first_y_prefix=8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C
1000053573.mp4  video_packets=900  decoded_frames=900  geometry=640x360  pixel_format=0  first_y_prefix=90909090909090909090909090909090
1000053574.mp4  video_packets=900  decoded_frames=900  geometry=640x360  pixel_format=0  first_y_prefix=98989695939291909090929395979898

The Y prefix is the first 16 bytes of the first decoded luminance plane and is acceptance evidence, not a visual fingerprint contract.

Direct v0.48 invariant-reduction acceptance (`16x9`, every 15th frame, 3x3 samples/cell, frame-global luminance removed, residual threshold 12):

1000053572.mp4  sampled_frames=60  active_cells=33  invariant_cells=111  invariant_share=0.770833333  changed_observations=117
1000053573.mp4  sampled_frames=60  active_cells=38  invariant_cells=106  invariant_share=0.736111111  changed_observations=133
1000053574.mp4  sampled_frames=60  active_cells=8   invariant_cells=136  invariant_share=0.944444444  changed_observations=19

These values are tied to the exact fixture hashes and reducer parameters. They demonstrate fixed-scene elimination, not semantic object classification.

Direct v0.49 adaptive hierarchy acceptance over the exact v0.48 16x9 activity maps (max depth 8):

1000053572.mp4  fine_cells=144  active_fine=33  adaptive_leaves=67  invariant_leaves=34  active_leaves=33  saved_leaf_records=77  leaf_share=0.465277778
1000053573.mp4  fine_cells=144  active_fine=38  adaptive_leaves=58  invariant_leaves=20  active_leaves=38  saved_leaf_records=86  leaf_share=0.402777778
1000053574.mp4  fine_cells=144  active_fine=8   adaptive_leaves=25  invariant_leaves=17  active_leaves=8   saved_leaf_records=119 leaf_share=0.173611111

Each invariant leaf may cover multiple fine cells. Active fine cells are preserved exactly as active leaves at the qualified maximum depth. The hierarchy is a representation/compression layer over the same activity evidence, not a second detector.

Direct v0.50 temporal primitive acceptance over the exact v0.48 luminance reducer settings:

1000053572.mp4  comparisons=59  regions=61  tracks=23  persistent_tracks=19  longest_track_observations=6
1000053573.mp4  comparisons=59  regions=36  tracks=16  persistent_tracks=10  longest_track_observations=5
1000053574.mp4  comparisons=59  regions=7   tracks=4   persistent_tracks=3   longest_track_observations=2

Changed cells are grouped using four-neighbour connectivity. Regions are linked only to the immediately preceding sampled comparison using overlap first and otherwise bounded Manhattan grid-centre distance. IDs are transient clip-local LT<n> identifiers.

Direct v0.51 peer-behaviour acceptance from decoded MP4 -> luminance regions -> temporal primitives -> Camera behaviour vectors:

1000053572.mp4  persistent_vectors=19  peer_subjects=19  peer_outliers=6  strongest=LT5   strongest_score=7.80003894
1000053573.mp4  persistent_vectors=10  peer_subjects=10  peer_outliers=5  strongest=LT9   strongest_score=19.1051383
1000053574.mp4  persistent_vectors=3   peer_subjects=0   peer_outliers=0  strongest=      strongest_score=0

The third fixture intentionally produces no peer assessment because three total vectors provide only two peers per subject, below the configured minimum of three. The outlier counts above describe coarse clip-local luminance-motion primitives and are not semantic subject/offence counts.

Direct v0.52 primitive-quality acceptance using established `16x9`, every-15th-frame, threshold-12 temporal primitives and quality minimum score 4:

1000053572.mp4  raw_tracks=23  persistent_vectors=19  qualified_vectors=13  peer_subjects=13  qualified_peer_outliers=1
1000053573.mp4  raw_tracks=16  persistent_vectors=10  qualified_vectors=3   peer_subjects=0   qualified_peer_outliers=0
1000053574.mp4  raw_tracks=4   persistent_vectors=3   qualified_vectors=0   peer_subjects=0   qualified_peer_outliers=0

Observed rejection reasons include `TOO_SHORT`, `STATIC_FRAGMENT`, `EDGE_DOMINATED`, and `SIZE_UNSTABLE`. These are primitive-quality diagnostics, not semantic labels for physical subjects.

Direct v0.53 source-boundary acceptance:

1000053572(1).mp4  sampled_frames=60   source_boundaries=0  source_segments=1
1000053603.mp4     sampled_frames=120  source_boundaries=1  dominant_pts_ms=59970  changed_share=0.784722222  structure_delta=29.0312636
1000053605.mp4     sampled_frames=120  source_boundaries=1  dominant_pts_ms=59970  changed_share=0.729166667  structure_delta=25.8352346

The 59970 ms values are observed decoded-frame media timestamps from these exact files, not hard-coded expected midpoints. Future fixtures may differ.

v0.53 scene prior / direction example for 1000053572(1).mp4:
active_cells=33, comparisons=59
direction_steps=38: U=2 D=1 L=9 R=7 UL=4 UR=2 DL=4 DR=0 stationary=9.

Direct v0.54 state-barrier acceptance:

1000053572(1).mp4  generations=1  G1 samples=1-60 comparisons=1-59
1000053603.mp4     generations=2  boundary=59970ms  G1 samples=1-60 comparisons=1-59  G2 samples=61-120 comparisons=61-119
1000053605.mp4     generations=2  boundary=59970ms  G1 samples=1-60 comparisons=1-59  G2 samples=61-120 comparisons=61-119

For each mixed fixture, comparison 60 (sample 60 -> sample 61) is source-replacement evidence and is deliberately absent from both motion generations. Segment-local priors and peer populations are reconstructed independently.

Direct v0.55 cross-clip scene-memory acceptance:

1000053572(1).mp4 -> SG1 initial scene fingerprint
1000053573(1).mp4 -> SG1 similarity=0.695502392
1000053574(1).mp4 -> SG1 similarity=0.90

After the three same-camera clips:
scene_generation=SG1
segments=3
comparisons=177
recurring_low_quality_artifact_zones=5
cell 5,4 active_segment_share=1
cell 11,4 active_segment_share=1

Then 1000053603.mp4:
segment 1 continues SG1
CSB1 at 59970 ms forces segment 2 into fresh SG2
SG2 inherits zero recurring artifacts from SG1.

The source key used in acceptance is `OUTDOOR3`; it is caller-provided camera/source context, not inferred identity.

Direct v0.56 scene-aware primitive acceptance:

Learn memory from:
1000053572(1).mp4
1000053573(1).mp4

Learned recurring nuisance zones after two clips:
TOO_SHORT @ 5,4
TOO_SHORT @ 11,5
STATIC_FRAGMENT @ 2,5

Assess 1000053574(1).mp4 before adding it to memory:
LT1 @ 6,4  TOO_SHORT       -> NOVEL_LOW_QUALITY_FRAGMENT
LT2 @ 7,4  STATIC_FRAGMENT -> NOVEL_LOW_QUALITY_FRAGMENT
LT3 @ 11,5 STATIC_FRAGMENT -> EXPECTED_SCENE_ACTIVITY (recurring zone; historical reason TOO_SHORT)
LT4 @ 5,4  STATIC_FRAGMENT -> EXPECTED_SCENE_ACTIVITY (recurring zone; historical reason TOO_SHORT)

Totals: observations=4, expected_scene=2, novel_fragment=2, admitted_motion=0, no_context=0.

After the detected CSB1 boundary in 1000053603.mp4, the fresh post-barrier generation contains zero inherited recurring nuisance artifacts; zones 5,4 and 11,5 are not known there until independently relearned.
