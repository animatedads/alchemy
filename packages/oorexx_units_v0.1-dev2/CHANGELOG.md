# Changelog

## 0.1-dev2

- Added absolute-temperature / temperature-delta arithmetic.
- Added compound-unit construction and parser (`*`, `/`, integral `^`).
- Added quantity metadata schema and round-trip reconstruction.
- Added volume, density, pressure, electronvolt and electromagnetic engineering units.
- Added common UTF-8 input aliases for ohm and temperature symbols.
- Hardened semantic-family equality for dimensionless quantities such as angle versus ratio.
- Established 50-digit internal arithmetic boundaries to prevent caller/default precision leakage.
- Extended qualification and runner to include dev2 tests, example execution and `rexxc`.


## 0.1-dev1

- Added independent seven-base-SI dimensional algebra.
- Added quantity objects retaining canonical value, source unit and display unit.
- Added replayable conversion proof objects.
- Added affine Celsius/Fahrenheit conversion via canonical kelvin.
- Added mechanics, electrical, photometric, metric-prefix and selected imperial units.
- Added semantic family refinement for equal-dimension units such as candela/lumen.
- Locked Maths v0.8 vector scaling semantics: vector division is reciprocal multiplication.
- Qualified against ooRexx 5.3.0 r13196 supplied debug build.
