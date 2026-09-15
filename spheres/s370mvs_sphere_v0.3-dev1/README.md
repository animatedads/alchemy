# s370mvs sphere v0.3-dev1

Declarative LLM Gopher sphere for IBM System/370 / OS/360 MVT/MVS emulator archaeology.

This authored increment is maintained independently of emulator safety checkpoints and is qualified with **LLM Gopher v0.21-dev1** from `oorexxapis(20260906-192237).zip`.

## Activate

```sh
gopher sphere load s370mvs --override ./s370mvs_gopher_sphere_v0.3-dev1.zip
gopher --profile s370mvs context s370mvs --full
gopher --profile s370mvs lookup opcode=70 --sphere s370mvs
gopher --profile s370mvs lookup checkpoint=safety23 --sphere s370mvs
```

## Evidence model

The sphere keeps IBM documentation, independent executable references, exact project evidence, live/permanent replay qualification, and sealed checkpoint identity as distinct claim levels. Unknown facts remain explicit.

Safety21, Safety22 and Safety23 are sealed provenance. Safety23 proves the historical X'70'/STE invalid-register specification exception separately from normal STE implementation coverage; `OP70` remains absent. The current causal boundary is implemented X'44'/EX targeting `70E005C84780`, whose architectural-exception attribution is the next task.
