# Live integration contract

The host constructs the existing authorities and injects them into the workbench:

1. Semantic Source Store / SCCD authority.
2. `SemanticSourceDevelopmentDesk` over that authority.
3. Current `IntentionService`, configured by `SemanticSourceDevelopmentDeskIntention`.
4. Existing configured ooRexx `ApiClient` using the estate's native HTTP/TLS implementation.
5. `AzureLunaApiClientTransport` wrapping that already-configured API Client.
6. `LlmCodingDeskSession`, `LlmCodingIntentionGateway`, and `LlmCodingWorkbench`.
7. A project verifier that compiles/tests materialised source and returns structured evidence.
8. `LlmCodingHostLoop` to run one model-selected semantic action per turn.

The workbench intentionally does not duplicate API Client construction, Azure credential discovery, SCCD storage setup, Intention registration, or the project's test runner.

## Required live invariants

- Luna receives semantic class/method objects and function button definitions.
- One Responses turn yields exactly one function call.
- The exact function argument object is staged into the structured Intention provider.
- Intention must return READY and COMMIT before a Desk mutation.
- Desk evidence is re-read from semantic source before the next model turn.
- Compile/test results are returned as structured verification objects.
- REPORT is itself passed through Intention policy/commit.
- Package path/object identity and actor remain host/session authority.

## dev6 materialise / verify loop

`LlmCodingMaterialisedVerifier` closes the loop after a source-changing action:

1. request `MATERIALISE` from the existing Development Desk;
2. re-read the authoritative semantic method;
3. build `oorexx.llm-coding.verification-request/0.1` containing the materialised source, semantic method object, target identity and action result;
4. invoke an injected verification checker;
5. return `oorexx.llm-coding.verification/0.2` to the next model turn without flattening compiler/test diagnostics.

The workbench does not implement another child-process layer.  The checker is the host/toolchain seam.  When the estate `oorexx_process` authority is available it should own `rexxc` and project test execution.

`REPORT` is now controller-gated: a model cannot complete a coding challenge until a structured verification `PASS` exists.  A verified REPORT still goes through Intention Service READY/COMMIT.

For a full real Semantic Source Store session use:

```sh
OOREXX_ROOT=/path/to/extracted-r13196 \
CODING_INTENTION_ROOT=/path/to/coding_intention_v0.1-dev13 \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev9 \
SEMANTIC_SOURCE_STORE_ROOT=/path/to/oorexx_semantic_source_store... \
./tools/run_real_semantic_method_session.sh
```

That script creates a package/class/method through Development Desk, drives semantic Coding Intention steps through the workbench, writes the generated method through Intention Service, materialises from source authority, compiles the resulting source with r13196 and executes a runtime behavior probe.
