# Renderer conformance status — v0.3

| Renderer | Real head evidence | Shared gates | Full PASS |
|---|---|---:|---|
| Web | JS dev6 integration pin; real adapter still open | not measured | No |
| Swing | dev12, 61/61 PASS | 8/10 | No |
| GTK / Direct Linux | dev41, real native/static evidence | 3/10 | No |
| Android | renderer checkpoint dev7 | not measured | No |

Swing still lacks published ResourceRef consumption and positive-list observation subscription. Direct Linux still lacks exact definition/resource identity, revision evidence, workspace context, observation subscription and deauthorisation/resync.
