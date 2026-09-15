# Changelog

## v0.5

- Rebound provider behavioral objects to Alchemy Objects v0.7 and AI Access v0.5.
- Advanced the optional OpenAI-compatible WLU planner contract to v0.4 and requalified against Work Load Units v0.11.
- Preserved mode-0600 curl credential transport, structured-message/tool wire mapping, conservative input accounting, and provider-reported actual settlement.
- Updated the immutable Runtime Registry fixture generation from v4 to v5 consistently across pin, artifact, and Ability profile.

## 0.4

- Advanced the generic dependency to AI Access v0.4.
- Added provider-specific OpenAI-compatible mapping for structured `user`, `assistant`, and `tool` messages.
- Added assistant tool-call and `tool_call_id` result mapping while keeping execution authority outside the provider.
- Extended the fake transport and real provider qualification with structured continuation traffic.
- Advanced optional OpenAI-compatible WLU admission to v0.3: conservative planning now includes serialized structured-message bytes and explicit wire-expansion allowance in addition to prompt/tool bytes.
- Proved conversation/tool-result contents are absent from planner and provider instrumentation.

## 0.3
- Advanced the generic dependency to AI Access v0.3.
- Added OpenAI-compatible function-tool request encoding from provider-neutral `AIProviderToolDefinition` values; internal Ability ids never enter provider JSON.
- Added `message.tool_calls` decoding into detached provider-neutral `AIProviderToolCall` values, including JSON-string argument parsing and bounded malformed-response rejection.
- Tool-call replies may carry null textual content when at least one valid tool proposal exists.
- Advanced optional OpenAI-compatible WLU admission to v0.2: conservative input reservation now includes serialized model-visible tool-definition bytes as well as prompt bytes.
- Added non-disclosure tests proving tool arguments and tool schemas do not enter Alchemy instrumentation.
- Retained the Secret Broker/curl credential boundary and provider-reported actual usage settlement.

## 0.2
- Added `OpenAICompatModelPolicy`, a shared plain allowlist/output-cap value object used without widening the provider request authority boundary.
- Added optional `OpenAICompatWLU.cls` for Work Load Units v0.3 pre-admission.
- Added conservative token-budget policy and estimator. The default reserves two input tokens per prompt byte plus 512 framing tokens and explicitly makes no exact-tokenizer claim.
- Added environment-driven WLU policy construction that reads model/output/WLU policy only and does not read endpoint or credential configuration.
- Added planner-side model/output rejection before WLU reservation and before Runtime Registry dynamic provider execution.
- Added full Runtime Registry + Ability HTTP + WLU acceptance proving conservative reservation, provider-reported actual settlement, unused-reservation refund and deterministic 429 capacity denial before provider execution.
- Retained the v0.1 Secret Broker and curl credential boundary unchanged in principle.

## 0.1
- Initial OpenAI-compatible provider adapter for AI Access v0.2.
- Added frozen endpoint/model policy and opaque credential-reference deployment config.
- Added HTTPS-default curl JSON transport with secret-bearing header isolated to a mode-600 temporary config rather than argv.
- Added bounded status/error mapping and OpenAI-compatible response/usage decoding.
- Added no-argument Runtime Registry module configured from deployment environment.
- Added deterministic transport tests for success, model-policy denial, output cap, 401, 429, malformed JSON, prompt non-disclosure and credential non-disclosure.
- Added real-curl acceptance against a one-shot ooRexx socket fixture server.
