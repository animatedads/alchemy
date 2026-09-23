# Source provenance

Development base:

- `oorexx_physics_world_v0.1-dev2.1.zip`, SHA-256 `422aa65309639653db333fe1dcc58b41314ac3e7e747b848d1734c5a77b112ce`;
- authoritative user-supplied `oorexx_maths_v0.8(2).zip`, SHA-256 `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`;
- independent `oorexx_units_v0.1-dev1.zip`, SHA-256 `e400465a2730ef0fe4e7db064354abc2c24d6e8c1fbf1879140d29aa2735f7ee`;
- ooRexx 5.3.0 r13196 debug runtime for qualification.

## Dev3 source

Acoustics, physical mounting and cross-domain qualification are project-local ooRexx source. No Python physics or acoustic solver is included.

The development air/water density and sound-speed values are explicitly approximate reference states for deterministic qualification, not metrology tables. The ideal `AcousticToneSource` represents already-radiated acoustic power; future speaker/transducer models must derive that power from their electrical/mechanical state rather than treating electrical input watts as acoustic watts.

The Units migration does not copy Units source into Physics. Physics loads `Units.cls` as a dependency and retains only compatibility class/catalogue names.
