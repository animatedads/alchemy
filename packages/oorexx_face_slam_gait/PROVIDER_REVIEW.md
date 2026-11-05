# Face SLAM pose / gait provider review (4 Nov 2026)

Implementation boundary: external inference engines are implementations of Alchemy Perception operations, not owners of gait semantics, tracking, or candidate authority. Python-based providers are accessed via ooRexx Foreign Runtime or ooRexx Python Macrospace bridge. This candidate contains **no** Python service and performs no inference.

| Provider | 2-D landmark topology | Foot / heel points | License considerations | First use |
| --- | --- | --- | --- | --- |
| Google MediaPipe Pose Landmarker | 33 landmark positions | indices 29-32 | Apache-2.0 | First local on-device candidate |
| OpenMMLab MMPose RTMPose | Depends on model/config (often COCO-17) | Need specific model | Apache-2.0 core; check model/algorithm weights | Independent comparator |
| Ultralytics YOLOv8/YOLO11 Pose | COCO-17 (typical pretrained human pose) | Not in baseline COCO-17 | AGPL-3.0 or Enterprise | Optional multi-person comparator after licensing review |
| FreeMoCap | Multi-camera / dependent on tracking backend | Depends on backend | **AGPL-3.0, not MIT** | Reference for multi-camera geometry |
| CMU OpenPose | BODY_25 and other configurations | Body/foot supports depending on configuration | Free noncommercial; commercial terms separate | Historical benchmark only |

MediaPipe's 33-point world result is an estimate produced by a monocular model. Without actual camera calibration/multiview reconstruction it must not be labelled measured 3-D position. No sub-millisecond benchmark is accepted: old BlazePose documentation reports approx. 20–53 milliseconds per frame on Pixel 3 GPU, 25–38 milliseconds on 2017 MacBook Pro, depending on model.

Source notes:
- Google docs: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker
- Google pose landmarks: https://ai.google.dev/edge/api/mediapipe/python/mp/tasks/vision/PoseLandmark
- Ultralytics pose COCO topology: https://docs.ultralytics.com/datasets/pose/coco
- Ultralytics license: https://www.ultralytics.com/license
- MMPose license: https://github.com/open-mmlab/mmpose
- MMPose special licenses: https://github.com/open-mmlab/mmpose/blob/main/LICENSES.md
- FreeMoCap license: https://github.com/freemocap/freemocap
- OpenPose license: https://github.com/CMU-Perceptual-Computing-Lab/openpose

## Execution gate

Qualification order: authoritative source PTS; image dimensions / normalization; model and weight digest; per-joint confidence; pose-to-track association from Motion Control; geometry using ooRexx Maths; train/eval splits that prevent adjacent frames inflating confidence; human review and no unqualified identity assertion.

This dev1 code emits **descriptive 2-D kinematic observations only**. Counting ankle crossing alternations does not establish walking step counts. Turn, perspective, camera shake, occlusion, treadmill movement, uneven ground and carrying objects require separate gates before gait-cycle metrics can be interpreted. Add heel strike / toe-off detection only after enough source-timed foot landmarks, calibrated camera geometry, and manually scored sequences are available.
