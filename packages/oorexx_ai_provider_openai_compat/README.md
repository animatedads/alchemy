# ooRexx AI Provider — OpenAI Compatible v0.6

v0.6 keeps the v0.5 AI Access/OpenAI-compatible request and reply projection but makes transport authentication an explicit deployment property:

- `BEARER`: OpenAI-style `Authorization: Bearer ...` via Secret Broker.
- `API_KEY`: Azure-style configurable key header, default `api-key`, via Secret Broker.
- `NONE`: no credential materialization, intended for loopback llama.cpp OpenAI-compatible endpoints.

Provider/model policy remains separate from worker authority. `NONE` does not permit arbitrary cleartext network endpoints; `LlamaCppProviderConfig` accepts loopback HTTP only.

Azure and llama.cpp therefore present the same `AIProviderRequest` / `AIProviderReply` semantics to AI Access and Development Floor.
