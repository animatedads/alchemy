# Dependencies

Required:

- ooRexx 5.3.0 r13196 qualification baseline;
- ooRexx Maths v0.8 (`oorexx_maths_v0.8(2).zip`), SHA-256 `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`;
- ooRexx Units v0.1-dev1 (`oorexx_units_v0.1-dev1.zip`), SHA-256 `e400465a2730ef0fe4e7db064354abc2c24d6e8c1fbf1879140d29aa2735f7ee`;
- RxMath from the selected ooRexx distribution.

Physics does not vendor or fork Maths or Units.

## Authority split

Maths v0.8 remains authoritative for 3-D algebra and transform semantics.

Units v0.1-dev1 is now authoritative for dimensional quantities and conversions. The historical Physics names `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` and `SI` are compatibility facades only. Physics-specific acoustic units not yet present in the shared catalogue are constructed as ordinary `UnitDefinition` objects using the Units dimensional authority.

Acoustics introduces no Python/native solver dependency. It uses RxMath trigonometric/logarithmic functions and the existing Maths/Units/Physics surfaces.

Rexx-tronics remains a consumer/integration peer, not a hard dependency.
