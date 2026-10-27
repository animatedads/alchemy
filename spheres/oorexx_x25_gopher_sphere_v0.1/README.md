# X.25 / XTP Gateway Gopher Sphere v0.1

**Architecture:** Tom Dyer. **Coding:** ChatGPT (GPT-6). **This sphere written by:** ChatGPT (GPT-6), 2026-10-25.

Canonical architecture lives in `docs/{X25_FAMILY_SPEC,XTP_GATEWAY_SPEC,SEMANTIC_MAPPING,OPEN_QUESTIONS,NOT_CLAIMED}.md`.

Source now admitted for review only: `packages/oorexx_x25_v0.1-dev1/src/{X25Packet,X25VirtualCircuit}.cls`, tested by three real ooRexx scripts and a deterministic runner. That is **not** a whole X.25 implementation.

Read `X25_SPHERE.md` for authority, current qualified boundaries, outstanding dependencies and what to work on next. This sphere documents the source and does not confer live deployment authority.

**27 Oct 2026 update:** `packages/oorexx_x25_v0.1-dev2` supersedes dev1 for the laboratory codec and VC skeleton after Claude's F1–F6 review; see `X25_SPHERE.md` and `docs/QUALIFICATION.md` inside the dev2 package. XTP dev30's `docs/DIAG_REGISTRY.md` is authoritative for gateway refusal VALUE 16–23. No LAPB or live network qualification is claimed.