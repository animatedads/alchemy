# Sydney Harbour Camera 2 — V5V registration v0.25

**Status:** one user-supplied screenshot registered and codec-qualified, **NOT** a live motion run. Architecture: user. Implemented 2026-11-01.

## Source and geometry

- User-supplied YouTube live source: https://www.youtube.com/live/9gWIZNLV5Fk
- Original screenshot `1000066480.jpg`, SHA-256 `cb614305b3f9f9417e2968cead937e8e759515fe99fbe3de7eaa6360933f752c`.
- Screenshot 1536×709; actual 1260×709 camera viewport at x=138, y=0. Black side letterbox excluded before reduction.
- Overlay reads **2026-11-01 11:49:15 AEDT** (2026-11-01T00:49:15Z), **camera clock unverified**.
- No exact physical camera position, calibration, azimuth, or inter-camera relation claimed.
- Visible alignment landmarks: Harbour Bridge, Opera House, skyline and wharves. These are kept in the complete V5V source surface, despite being masked out of **water motion admission**.

## Native V5V and motion-mask evidence

The screenshot's central viewport was reduced to an RGB24 80×45 scene (10,800 input bytes). The existing Vision-dev22 palette/five-bit keyframe logic reconstructed **all 3,600 indexed cells exactly** from a **2,250-byte packed V5V keyframe**. This is *indexed-surface* equality, **not** original JPEG reconstruction.

`cam2.water_bitmap.psv` encodes 45 exact 80-cell binary rows. **655/3600 cells** are provisionally admitted for water-motion discovery; **2,945 cells excluded** from that particular search, not from V5V storage. The mask handles disjoint water regions and excludes timestamp overlay and park/shoreline. Three separately configurable detection lines are WEST_CHANNEL, CENTRAL_CHANNEL and EAST_CHANNEL, all **PROVISIONAL_NOT_USER_TRACED**. This is a separate camera-specific view from Sydney Camera 1.

The photo supplies visible vessel *candidates* (a motor craft/wake and sailboat), **not** movement or ferry labels. A still frame produces **zero temporal movement detections**. Never turn static JPEG objects into confirmed motion.

## Runtime qualification (executed)

- Source JPEG SHA-256 and screenshot/viewport dimensions: verified.
- Native V5V codec: **1/1** exact indexed keyframe.
- Native line scanner: three valid gates, **0** movement detections on still.
- Legacy row-mask codec parity on three outputs: **3/3 byte identical**.
- Legacy row-mask scanner parity: **2/2 byte identical**.
- Eight deliberate negative cases: **8/8 rejected** (nonbinary bits, reordered rows, forged authority, truncated mask, gate on land, false TESTED status, truncated V5V, forged source).
- Full live video: **NOT ACQUIRED**. No runtime vessel recognition, Camera 1 association, SLAM TESTED status or time-series motion claims.

## Reproduction and artifact

Local runnable package: `sydney_harbour_camera2_v5v_registration_v0.25.zip` SHA-256 `6aa11b307c68450e90f24ae0ed911dcc5c0591d73500193b35cddad3f9c8924c`. Contains exact source registration, native V5V+bitmap-mask C codec and scanner source, compilation/qualification shell runner, full-cadence external-video runner, mask, gates, source identifiers, 2,250-byte keyframe, SHA manifest and observed annotations. Original source screenshot deliberately omitted from bundle; its visible overlay says `NOT FOR REBROADCAST`.

`qualify_cam2.sh /path/to/1000066480.jpg` compiles and runs the one-frame proof; `run_cam2_clip.sh ORIGINAL_CAMERA_VIDEO.mp4 OUTPUT_DIR` requires a real captured clip and explicit `CAMERA_VIEW_STABLE=1` after landmark stability checks. The latter must preserve all original PTS and source-frame indexes.

**Next gates:** secure authorized original video, verify stable field of view, rerun full V5V series, acquire actual line-crossing/forecast motion, then issue bounded high-resolution lookup and qualify appearance against taught ferry examples. Do not conflate screenshot-only proof with a live stream qualification.
