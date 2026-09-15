# Provenance

Qualification inputs supplied on 2026-09-08:

- `oorexxapis(20260908-080803).zip` SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`
- `sphere(20260908-080803).zip` SHA-256 `293cd2a62e04965e7c87134902d0509bb453cbe36618f895444a0af7465fc177`
- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20260908-080830).deb` SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Consumed heads from the API roll-up:

- HTTPS Server `oorexx_https_server_v0.4.4.zip` SHA-256 `aad4305c2495b13145a71938c59af86bc8d128be8d466aaf7b3548468a252d56`
- Wire UI Server `wire_ui_server_v0.17.zip` SHA-256 `82c3a9d270d123dcbedabed1b57ed5e0944b828b1a184a5b71d47d9f9f188441`
- LLM Gopher `llm_gopher_v0.21-dev1.zip` SHA-256 `6fc0114f730a64470a4e4a819832f933bfc5e628af19bb8b920d860b205fe477`

`catalog/components.json` contains the exact SHA-256 of every top-level `current/*.zip` component captured from that API roll-up.

MCP protocol behavior targets specification revision `2026-07-28`; this is deliberately the stateless protocol era, not the retired initialize/session handshake.
