# Changelog

## v0.6

- Repaired the common AI behavioural bases to use preferred Alchemy Objects v0.7 non-virtual `INIT` construction instead of compatibility `initAlchemy()`.
- Added complete STANDARD adoption metadata (`AUTHORSHIP`, `STANDARDS`, `DESIGN_LIMITATIONS`) and executable zero-warning / zero-reserved-override adoption checks.
- Qualified Runtime Registry v0.14 and optional Work Load Units v0.12 (`work.load.units/0.12`).
- Kept the public provider API stable at `ai.provider.access/0.5`; this is a package/foundation qualification release, not a provider-request protocol change.
- Preserved the narrow provider/tool/conversation authority boundary and all existing WLU accounting semantics.

## v0.5

- Rebound behavioral AI Access objects to Alchemy Objects v0.7 without widening the plain provider-neutral DTO authority boundary.
- Requalified Runtime Registry v0.13 generation closure and optional Ability/WLU admission against Work Load Units v0.11 (`work.load.units/0.11`).
- Updated declared optional WLU requirement to v0.11.
- No tool-proposal, structured-message, provider metering, or generation-pinning semantics changed from v0.4.

## 0.4 - 2026-08-24

- Added plain provider-neutral `AIProviderMessage` for `user`, `assistant`, and `tool` conversation roles.
- Added call-id-bound tool-result messages and assistant messages containing detached `AIProviderToolCall` values.
- Extended `AIProviderRequest` with an optional bounded structured-message array while preserving prior constructor positions.
- Enforced prompt/messages exclusivity: structured-message requests require an empty legacy prompt.
- Extended Runtime decoding/profile schemas for generic structured messages and continued rejection of private `ability_id` injection.
- Added conversation qualification proving deep detachment and absence of message/tool-result content from instrumentation.
- Retained optional WLU v0.3 behavior and immutable Runtime Registry generation semantics.

## 0.3 - 2026-08-23

- Added plain `AIProviderToolDefinition` and `AIProviderToolCall` DTOs.
- Extended `AIProviderRequest` with an optional bounded tool-definition array and `AIProviderReply` with an optional bounded tool-call array while preserving text-only constructor compatibility.
- Tool schemas and returned argument objects are JSON-detached at the provider boundary.
- Runtime projection accepts model-visible `tools` and returns typed `tool_calls` as business data without exposing Ability ids or execution authority.
- Direct runtime decoding rejects unknown tool-definition fields, including attempts to smuggle an internal `ability_id`.
- Alchemy instrumentation records only definition/call counts; schemas and tool arguments are excluded.
- Runtime Registry dependency advanced to certified v0.13; WLU remains optional and actual provider usage remains the metering source.

## 0.2 - 2026-08-23

- Adopted `alchemy_objects_v0.4.3` for the behavioral AI access objects while deliberately keeping `AIProviderRequest`, `AIProviderUsage`, and `AIProviderReply` as narrow plain value objects.
- Added `AIProviderAdapterBase`, an `AlchemyObject`-derived provider adapter boundary with lifecycle, surface contracts and non-content instrumentation. Provider packages override `completeRequest()` while the base owns bounded completion telemetry.
- Made `AIProviderRuntimeCapability` inherit `AlchemyObject`, adding object identity, lifecycle counters, method/data contracts, external requirement declarations, provider relationship evidence and bounded invocation instrumentation.
- Added a generation-private bundling pattern for the minimal AlchemyObject source closure (`AlchemyEvidence`, `AlchemySecurity`, `AlchemyLockedMethod`, `AlchemyObject`) so immutable Runtime Registry generations do not depend on whichever base source happens to be found later on `REXX_PATH`.
- Added an explicit acceptance test proving that prompt contents are absent from provider/runtime Alchemy instrumentation while behavioral objects still emit lifecycle and method evidence.
- Sanitized unexpected provider exceptions at the generic boundary: raw condition messages are no longer returned to callers or copied into Alchemy instrumentation.
- Requalified optional Ability/WLU integration against `oorexx_work_load_units_v0.3` and its `work.load.units/0.3` evidence version.

## 0.1 - 2026-08-22

- Added provider-neutral `AIProviderRequest`, `AIProviderUsage`, and `AIProviderReply`.
- Added `AIProviderRuntimeCapability`, keeping the provider implementation behind a narrow request object while the runtime wrapper retains Ability/WLU responsibilities.
- Added the provider-specific WLU planner pattern with a deterministic qualification planner; pricing and admission remain external WLU authority concerns.
- Added bounded `model.complete` Ability Profile fixtures.
- Added deterministic V1/V2 provider packages proving immutable Runtime Registry generation pinning.
- Added tests for input-schema-before-execution, provider authority isolation, performed-work metering, 429-before-provider-execution, and business/execution metadata separation.
