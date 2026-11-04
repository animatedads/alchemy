# ooRexx String Template Gopher Sphere v0.1

Continuity sphere for the reusable ooRexx String Template component.

Current source baseline:

- package version `0.1-dev3` in `packages/oorexx_string_template`;
- generated dev3 carrier `oorexx_string_template_v0.1-dev3.zip` SHA-256 `65848f8bcd63376ff947da9729d880be6ca77e49dd5eab149458456227eace1a`;
- dev2 predecessor carrier SHA-256 `ec8cf86c920cf34a989bd03336a7e08ec0cd0e034675010438c3dab0063d34fc`.

Dev3 preserves the interpolation language while making formatter bindings deterministic. A template captures a sealed formatter-registry snapshot, can inspect missing formatter requirements without execution, and can create an explicitly rebound template with `withFormatters`.

The governing rule remains that a template is parsed data, not executable Rexx. Template syntax names controlled values and registered formatters; it does not gain arbitrary expressions, loops, conditionals, macros or implicit object method invocation.

The package remains runtime authority. This sphere is documentation and continuation authority only.
