# ooRexx Unix Socket Gopher Sphere v0.1

Authoritative continuity sphere for the ooRexx Unix-domain socket library.

This sphere documents the meaning and durable boundaries of `oorexx_unix_socket_v0.6.zip`: why stock `socket.cls` is not an AF_UNIX API; why `unixsocket.cls` remains the semantic layer while Foreign Runtime owns native binding; pathname/abstract/unnamed addresses; managed descriptor ownership; `SCM_RIGHTS` and credentials; poll/nonblocking behavior; socket-path safety; executable ABI authority; ABI-native C scalars versus qualified aggregate layouts; portability limits; qualification; and continuation doctrine.

The sphere is deliberately separate from the executable Unix Socket package. It is documentation/continuity authority, not runtime code.

Primary grounded artifacts:

- `oorexx_unix_socket_v0.6.zip` — SHA-256 `aea3f193e910b216b051b046cc9ea695089e7ed67013a1a1a412d1324199e326`
- `oorexx_foreign_runtime_v0.22.6(1).zip` — SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
- ooRexx 5.3.0 r13196 supplied `.deb` — SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Start with `gopher context unix-socket`, then open the articles named in `packs/unix-socket/00-sphere.json` `start_here`.
