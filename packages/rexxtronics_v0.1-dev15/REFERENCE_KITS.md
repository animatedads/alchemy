# Reference kit qualification

Rexx-tronics uses historical electronics-project kits as source-backed regression suites. The manuals are reference inputs and are not redistributed in this package.

## Maxitronix 500-in-1 Electronic Lab

Development source set supplied by the project owner:

- Hardware Entry Course: projects 1-254
- Hardware Advanced Course: projects 255-400
- Software Programming Course: projects 401-500

### Implemented electrical fixtures

**Project 7 — LIGHT TELEGRAPH**

The Hardware Entry Course project page specifies a 270-ohm resistor, an LED, the S1 key/switch, and the V2 3-volt supply. The project explanation describes a simple closed current path: when S1 is closed current flows through the resistor and LED, and the LED lights; when the key is open the path is broken.

`Maxitronix500Project007` encodes that electrical schematic with ordinary Rexx-tronics components. It deliberately does not yet encode the kit's physical breadboard row/column locations. Physical board topology is the next independent mapping layer and must resolve to the same electrical graph.

The generic LED parameters in this first fixture are solver-qualification values, not claimed manufacturer characteristics for the historical kit LED. Exact device parameters should later be replaced by source/datasheet-backed part definitions through the component-definition ingestion pipeline.


### Project 14 — MEET THE TRANSISTOR

The Hardware Entry Course supplies two schematics: a PNP demonstration using
12 kOhm / 470 Ohm resistors with stacked +6 V and +3 V sources, and an NPN
demonstration using 4.7 kOhm / 1 kOhm resistors with the manual's -7.5 V / -9 V
rail arrangement.  `Maxitronix500Project014PNP` and
`Maxitronix500Project014NPN` reproduce those electrical schematics.  Both
qualify the stated behaviour that S1 supplies base current and causes LED1 to
light through a much larger collector current.

The transistor model parameters are explicit qualification defaults because the
historical kit part is not identified here by an authoritative manufacturer
datasheet.

### Project 15 — TRANSISTORS AS SWITCHES

`Maxitronix500Project015` reproduces the +9 V NPN low-side display switch.  All
seven protected segment inputs are tied high; S1 drives Q1 through the specified
4.7 kOhm base resistor.  With S1 released the display is electrically dark.
With S1 pressed Q1 saturates and all seven solved segment currents are above the
light threshold, so `displayedDigit` derives the digit `8`.

The manual states that the display contains protective resistors but does not
specify their value on the project page.  The fixture therefore uses an
explicit 1 kOhm per-segment qualification value and does not present it as a
historical component specification.
