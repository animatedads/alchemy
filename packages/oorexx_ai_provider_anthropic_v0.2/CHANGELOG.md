# Changelog

## v0.2 (2026-08-24)

- Qualified the provider against `oorexx_ai_access_v0.6`, `alchemy_objects_v0.8`, and `oorexx_secret_broker_v0.2` while keeping the public `ai.provider.anthropic/0.1` protocol stable.
- Migrated `AnthropicCapabilitySelector` to preferred Alchemy v0.8 construction with complete STANDARD metadata; `AnthropicBatchProvider` is now a long-lived Alchemy object as well.
- Moved both real-time and Batch API-key acquisition behind `SecretBroker` short-lived leases. Secret material is obtained through `secretForTrustedConsumer()` only at the trusted curl boundary and leases are retired immediately after transport.
- Preserved the old environment-source constructor as a compatibility adapter; provider execution no longer directly reads the credential environment variable.
- Added executable fake-curl coverage for both real-time and Batch paths proving the API key is absent from argv, the temporary curl configuration is mode 0600, the expected `x-api-key` header is materialized there, and no lease remains active afterwards.
- Renamed Batch transport outcome locals away from the special Rexx variable name `RESULT` as defensive ooRexx hygiene and added actual Batch create execution to the non-network suite.


## v0.1 (2026-08-23)

- Initial release: `AnthropicCapabilitySelector` (zone + capability-tier
  filtering, then cheapest-eligible ranking; explicit anti-default-to-
  flagship rule), `AnthropicModelCatalog`, `AnthropicChannel`
  (direct/Bedrock/Vertex, with data-sovereignty zone modeling),
  `AnthropicWorkloadProfile`, cost estimation, job-cost ledger
  (`recordJobCost`/`queryJobCost`/`settleJobCost`).
- `AnthropicProvider` (real-time, `/v1/messages`) and
  `AnthropicBatchProvider` (`/v1/messages/batches` create/get/results/cancel)
  live transport for the direct channel, subclassing
  `AIProviderAdapterBase` from `oorexx_ai_access_v0.2`.
- Verified live against the real `api.anthropic.com` (both the completion
  and batch-create endpoints correctly reached and their real error shape
  correctly parsed, given no valid credential was available in the build
  environment).
- Bedrock/Vertex channels are modeled for routing/cost decisions only;
  signed transport for those channels is out of scope for v0.1.
