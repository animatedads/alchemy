# ooRexx Common Parts v0.1-dev2

An independently maintained catalogue of reusable physical/electrical parts.

This package does **not** own circuit physics, material physics, or manufacturing simulation. It owns reusable part identity, rated/default parameters, material-role references, package/geometry metadata, manufacturing descriptors, provenance notes, and adapters that instantiate authoritative Rexx-tronics behaviour.

Initial catalogue: generic axial resistors, generic capacitors, 1N4148, 1N4007, generic 5.1 V Zener, generic red 5 mm LED, plus a small bench set.

The 1N4148/1N4007 entries deliberately separate published/common ratings from deterministic piecewise-linear simulation parameters. They are not manufacturer-lot guarantees.

## v0.1-dev2
Rebased qualification/projection support onto Rexx-tronics v0.1-dev15. The starter bench catalogue now also includes a wound inductor, rotary potentiometer, SPST switch, common 2N2222-style NPN model, and a generic red common-cathode seven-segment display. These remain catalogue definitions: Rexx-tronics owns their electrical behaviour and manufacturing/Physics owns evolving physical instances.
