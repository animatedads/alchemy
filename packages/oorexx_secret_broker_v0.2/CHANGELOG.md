# Changelog — ooRexx Secret Broker

## 0.2 — 2026-08-24

- Clean-room recovery successor to the previously certified but currently unavailable v0.1 archive.
- Adopt Alchemy Objects v0.7 using preferred `INIT` construction.
- Preserve Grok/OpenAI compatibility surfaces: `SecretBroker`, `SecretLease`, `TestSecretProvider`, `MappedEnvironmentSecretProvider`.
- Support result-style (`ok`/`value`, `secretForTrustedConsumer`, `retire`) and legacy direct-lease (`secretValue`, `release`) consumers.
- Explicit non-disclosure instrumentation and lease retirement tests.
