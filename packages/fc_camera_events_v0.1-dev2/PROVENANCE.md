# FC Camera Events v0.1-dev2 provenance

## Origin

v0.1-dev2 extends the qualified `FC Vehicle Motion v0.1-dev1` worker without
changing the distributed worker boundary or file-relative timestamp authority.

The additional visual regions were specified by the user using two annotated
FC reference images:

- red diagonal: thin traffic sight line through which vehicles are visible;
- blue diagonal: physical window state region;
- closed-window night view: room reflection visible in the glass.

The first interrupted dev2 edit had already introduced the normalized region
scaffolding and evidence classes. The recovered dev2 completes the decoder
integration, persistence logic, output contracts, qualification and
documentation rather than discarding that work.

## Decoder / timing authority

The FFmpeg bridge descriptors remain byte-for-byte inherited from Camera
Behaviour ooRexx v0.56. Public timestamps are based on decoded video
`AVFrame.pts * AVStream.time_base`, normalized to the first decoded frame.

No filename timestamp, audio timing correction, `FILE_EDGE_MAP.tsv`, wall
clock, SSH state or BashQueue timing is consulted when creating an event time.

## Classification authority

`TRAFFIC_MOTION` is the unified presentation of an admitted `CAR_MOTION`
episode in the FC road union mask. The mask explicitly includes the
user-annotated red traffic slit and records slit-contact evidence.

`WINDOW_OPEN` / `WINDOW_CLOSED` are persistent photometric state observations
from the user-annotated blue diagonal region. Ambiguous ratios remain
`UNKNOWN` in scene evidence and are not forced into a state interval.

`ROOM_REFLECTION_VISIBLE` requires a `CLOSED` window classification plus
persistent structured-edge evidence in the glass/exterior field. Texture by
itself has no authority to declare a reflection.

None of these classes identifies a person, vehicle identity, registration
plate or vehicle make/model.

## Operational authority

The ooRexx worker owns only local analysis and output generation. Codex and
BashQueue own SSH, transfer, job submission, collection and deletion of the
temporary node-local video after successful evidence harvest.
