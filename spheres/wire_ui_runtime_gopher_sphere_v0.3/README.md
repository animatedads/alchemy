# Wire UI Runtime Gopher Sphere v0.3

Authoritative continuity sphere for the Wire UI runtime/access-point layer: logical Comms, Queue Fabric gateway semantics, Web readiness, exact ResourceRef consumption and cross-renderer semantic agreement across Web, Swing, GTK/Direct Linux and Android.

v0.3 rebases runtime evidence on the 29 October heads and adds executable real-head conformance/readiness evidence from `wire_ui_renderer_conformance_v0.3`.

Current measured renderer state:
- Swing dev12: 61/61 tests PASS, 8/10 shared semantic gates.
- Direct Linux dev41: native C/loader/filter and dev41 authority/static tests PASS; 3/10 shared gates; QuickJS/GTK4 native compilation skipped where dev libraries are absent.
- Web and Android still require real v0.3 adapters.

Rasen Falcon runtime status is deliberately fail-closed: v0.4.4 has a real review stage, but exact HTTPS 0.4.8 runtime/live TLS, LDAP installation/live LDAPS, release admission and live Wire browser roundtrip are still gates. Source-only or staged-only is not running.

Sibling authorities remain separate: `wire-ui` owns shared presentation semantics; `wire-ui-builder` owns authoring/compile continuity; `wire-ui-swing` owns Swing mechanics; this sphere owns runtime/access-point and cross-renderer agreement seams.
