# ooRexx Common Parts v0.1-dev5

An independently maintained catalogue of reusable physical/electrical parts.

This package does **not** own circuit physics, material physics, or manufacturing simulation. It owns reusable part identity, rated/default parameters, material-role references, package/geometry metadata, manufacturing descriptors, provenance notes, and adapters that instantiate authoritative Rexx-tronics behaviour.

## Scope (dev5)

Substantial extension of the catalogue with parameterised families:

- **Fasteners** – ISO coarse metric bolts M2–M12 (hex / socket / countersunk), nuts, nyloc nuts, plain & spring washers, threaded rod, set screws. Geometry standard-derived; capacity derived from Materials yield when available.
- **Bearings** – deep-groove 608 / 6000-series / 6200-series, open / ZZ / 2RS. Envelope geometry only; load/speed ratings omitted from the generic family.
- **Shaft & motion** – round shafts, collars, key stock, rigid / beam / jaw couplers, lead screws, GT2 belts & pulleys, spur gears, racks.
- **Springs** – compression, extension, torsion (geometry; rate derivation stays in Physics).
- **Structural stock** – plates, round/square bar, angle, SHS, RHS, tube (parameterised).
- **Packages** – DIP, TO-220, 0603/0805/1206 chip (reusable independently of electrical function).
- **Electromechanical** – brushed & geared DC motors, NEMA 17 stepper, hobby servo, solenoid, PCB relay (ratings/geometry only).
- **Thermal** – TO-220 heatsink, thermal pad, thermal paste layer.
- **Manufacturing tools** – drill bit, end mill, lathe insert, saw blade (geometry only; cutting physics in Physical Manufacturing).
- **Sensors** – thermocouple, PT100, strain gauge, load cell.
- **Batteries** – AA, AAA, CR2032, 18650, PP3 (physical/rating catalogue; electrochemistry stays out).

Plus the original electronics bench set (resistors, capacitors, 1N4148/1N4007, LEDs, BJTs, etc.).

## Ownership boundaries

| Package              | Authority                                      |
|----------------------|------------------------------------------------|
| Maths                | numerical                                      |
| Units                | dimensional / quantity                         |
| Materials            | substance properties                           |
| **Common Parts**     | part identity, geometry, ratings, material roles |
| Physics World        | physical-law / physical-state behaviour        |
| Rexx-tronics         | electrical / electromechanical behaviour       |
| Physical Manufacturing | process / tooling / material-removal         |

A `PartDefinition` is descriptive. Manufactured instances may heat, deform, wear or fracture; those changes do not mutate the catalogue definition.

## Provenance

Values are tagged by model grade (`STANDARD_GEOMETRY`, `ENGINEERING_REFERENCE`, `COMMON`, `GENERIC`) and by explicit provenance notes. Approximate or model-derived figures are never presented as manufacturer-certified.

## Dependencies

- ooRexx Materials ≥ v0.1-dev3
- ooRexx Units ≥ v0.1-dev4
- Rexx-tronics ≥ v0.1-dev15 (for the electrical factory only)
- ooRexx Maths ≥ v0.8 (via Units)

## Tests

```sh
./run_tests.sh
```

Requires the dependency roots to be discoverable (see `run_tests.sh`).
