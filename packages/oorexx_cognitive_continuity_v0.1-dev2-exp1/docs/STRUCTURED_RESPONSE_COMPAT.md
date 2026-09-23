# Structured Response compatibility note

The architecture requires the platform Structured Response API to own common result/receipt semantics. This package does not claim that ownership.

The supplied API roll-up was scanned for a standalone `StructuredResponse` implementation/package and none was identifiable. FlyLo does contain strict JSON-schema structured generation (`FlyLoStructuredAIRequest`, `schemaName`, detached `responseSchema`, provider strict JSON response formatting), which remains useful producer-side evidence but is not substituted here as a generic platform result class.

`CognitiveResult` is therefore internal to this experimental cut. `CognitiveStructuredResponseBridge` wraps it in `oorexx.cognitive.compat-structured-response/0.1` solely so MCP/LLMPA dog-food callers can inspect a stable detached result. Its schema explicitly says `compatibilityOnly=true`.

When the actual platform Structured Response package is available, dev2 should replace this bridge and leave cognitive domain payload schemas unchanged.
