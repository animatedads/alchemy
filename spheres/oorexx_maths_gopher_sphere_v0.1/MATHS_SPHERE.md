# ooRexx Maths Gopher sphere v0.1

Drop this archive into the root of LLM Gopher v0.14-dev1 (or a compatible later Gopher that preserves the semantic pack/profile contracts).

It adds only:
- `packs/maths/`
- `profiles/maths.json`
- `tests/run_maths_sphere.sh`
- Maths sphere qualification/manifest files

It does not replace `engine/gopher.py`.

Start with:

    ./gopher --profile maths context maths
    ./gopher --profile maths help maths --text
    ./gopher --profile maths open maths.current
    ./gopher --profile maths search '50 digits' --sphere maths
    ./gopher --profile maths search quadratic --sphere maths

To inspect the current source package:

    ./gopher --profile maths examine source Maths.cls \
      --in /path/oorexx_maths_v0.7.zip \
      --symbol MathQuantizationScheme --sphere maths

Qualification:

    MATHS_ZIP=/path/oorexx_maths_v0.7.zip ./tests/run_maths_sphere.sh
