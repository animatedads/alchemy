# Changelog

## 0.1-dev4
- Added practical SI-adjacent, imperial, US customary, marine and automotive units.
- Added mechanical horsepower (`hp`) and metric horsepower (`PS`) as distinct named units.
- Added `psi`, `atm`, `Torr`, `mmHg`, `cc`, UK/US gallons and related volume units.
- Bare `gallon`/`gal` now fails closed because the unit system is ambiguous.
- Added `kph`, nautical mile, knot, acre, customary masses, calorie/kcal and BTU.
- Added `test_practical_units.rex` to normal qualification.

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

## 0.1-dev3
- Expanded first-class engineering-prefix catalogue for electronics/physics presentation.
- Added microwatt, milliwatt, megawatt; microvolt, kilovolt; microampere, kiloampere; milliohm; millifarad; microhenry; gigahertz.
- Parser accepts ASCII `u` and Unicode micro forms (`µ`, `μ`) where applicable.
- Added direct parser coverage for existing kHz/MHz/kW catalogue entries.

## 0.1-dev3.1
- Repair `Units~version` so runtime version authority agrees with the package `VERSION` file.
- Include `test_engineering_prefixes.rex` in `run_tests.sh`.
- Compare engineering-prefix qualification values numerically rather than by textual representation, avoiding false failures such as `3300.0` versus `3300`.
- Add `test_package_version.rex` so `VERSION` and `Units~version` cannot silently drift again.
