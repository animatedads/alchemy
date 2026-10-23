# ooRexx LLM Coding Workbench Gopher Sphere v0.1

Project-continuity sphere for the **ooRexx LLM Coding Workbench**.

Grounded source delivery:

- `oorexx_llm_coding_workbench_v0.1-dev14.zip`
- SHA-256 `04429c32acf45c8926dff41c16fb7e73a25d4480ba7fa199ff1b28d960032899`
- GitHub package: `packages/oorexx_llm_coding_workbench`

The central architectural rule is deliberately simple: **keep the object whole
inside Rexx**. The Workbench has the live semantic objects, callable tools and
API context at the same time, so instrumentation and orchestration belong there.
Flattening to Directory/JSON is an explicit external boundary operation, not an
internal representation strategy. Python is not the Workbench controller.

The sphere also records the authority split: Semantic Source Store/Development
Desk owns source state; Intention Service owns interpretation/policy/commit;
Coding Intention owns language knowledge; API Client owns HTTP/TLS; the selected
ooRexx/toolchain environment owns compile/runtime truth. The Workbench
coordinates those authorities without absorbing them.

Current baseline is dev14. The last complete recorded r13196 environment run is
dev13; dev14 has a narrow source change and must be fully rerun before claiming
a dev14 runtime PASS.
