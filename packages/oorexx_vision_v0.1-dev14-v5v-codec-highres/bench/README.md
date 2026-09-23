# Termux three-target live bench

Positive camera fixture supplied during development:
`projector_three_targets_55x73.png`

Source capture was 1152x1536; it was reduced first to 55x73 = 4015 samples.
Target discovery must operate from that reduced evidence representation, not
from raw-resolution RGB.

Empirical local-contrast prototype:
threshold 7.0 produced exactly three compact components: [(7, 12, 30, 4, 2, 0.5, 0.875), (30, 27, 38, 8, 5, 0.625, 0.75), (15, 36, 38, 5, 4, 0.8, 0.75)]

This threshold is diagnostic evidence, NOT a wire-format constant and must not
be baked into Vision semantics.

Live acquisition:
    bash bench/termux_capture.sh

Qualification:
- positive scene: exactly 3 persistent compact projected regions;
- negative/off-target scene: must not manufacture 3;
- no hand, gesture, or 3D callback processing yet.
