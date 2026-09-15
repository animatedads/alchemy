# Google Colab Gopher Sphere v0.1

A grounded operational sphere for using Google Colab as ephemeral managed compute.

This sphere intentionally emphasizes the seams that repeatedly matter in automation:

- installed CLI capability vs upstream documentation;
- provider allocation request vs actual observed worker resources;
- control-plane auth vs workload secrets;
- ordinary configuration vs secret staging;
- transient transport faults vs deterministic install/workload failures;
- large convenience archives vs compact immutable payloads;
- execution/training success vs grading/promotion success;
- remote ephemeral state vs durable returned artifacts.

It is data-only. It adds `packs/google-colab` plus `profiles/google-colab.json`; it does not modify the Gopher engine or install Google Colab software.

## Start here

    ./gopher --profile google-colab context google-colab
    ./gopher --profile google-colab open ops.google-colab.overview
    ./gopher --profile google-colab lookup topic=compatibility --sphere google-colab
    ./gopher --profile google-colab search 'Connection was lost' --sphere google-colab

## Volatility posture

Google Colab and `google-colab-cli` change quickly. Runtime capability must be established by the installed `colab version` and `colab <command> -h`; current upstream `main` is reference material only. Version-specific project incidents are deliberately labelled as such.

## Rule posture

No language-rule files are shipped. Most failures here depend on runtime version, provider state, credential plane, or lifecycle stage rather than a reliable source-text trigger. Encoding weak grep-like rules would create false authority. The sphere therefore uses articles plus typed corpus records.
