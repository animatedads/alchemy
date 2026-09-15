# ooRexx Maths Gopher sphere v0.1

This pack is durable semantic context for the ooRexx Maths project. It deliberately contains decisions, baselines, proof/precision rules, provider boundaries, qualification state and continuation seams rather than duplicating the complete source package.

Use the `maths` profile, which layers `core + oorexx + maths` so the sphere retains ooRexx archive/source/rule/package capabilities.

Examples:

    ./gopher --profile maths context maths
    ./gopher --profile maths open maths.current
    ./gopher --profile maths search "NUMERIC DIGITS 50" --sphere maths
    ./gopher --profile maths search quadratic --sphere maths
    ./gopher --profile maths examine source Maths.cls --in /path/oorexx_maths_v0.7.zip --symbol MathQuantizationScheme --sphere maths

The ooRexx source examiner/editor services in the upstream oorexx pack are intentionally scoped to the `oorexx` sphere. This add-on publishes Maths-scoped service aliases to the same built-in implementations so source operations remain available under `--sphere maths` without changing or duplicating the engine implementation.
