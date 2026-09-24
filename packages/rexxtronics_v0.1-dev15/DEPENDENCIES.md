# Dependencies — Rexx-tronics v0.1-dev15

## ooRexx Units v0.1-dev4

Pinned unchanged under `deps/oorexx_units_v0.1-dev4/`.  It remains the sole units/dimensions/quantity authority.

Archive SHA-256: `b0916df3d8b68f1681f219e0e8770e490a6f7c00165cc5959b84d14354d4fa46`.

## ooRexx Maths v0.8

Pinned unchanged under `deps/oorexx_maths_v0.8/`.  Maths remains the authority for vector, matrix, quaternion and 3-D transform semantics.

Archive SHA-256: `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`.

## ooRexx Physics World v0.1-dev10.1

Pinned unchanged under `deps/oorexx_physics_world_v0.1-dev10.1/`. Physics remains a peer authority for mechanics, contact dynamics, deformable/fracture topology, structural vibration, acoustics, optics, one- and two-axis free-surface fluids, thermal behaviour and reciprocal electromechanical conversion.

Archive SHA-256: `936737a18d2c96a627e86d322b3dbf6bda06134a2410fc7eafb58c750cf6cc3c`.

Physics dev10.1 itself requires Maths v0.8, Units v0.1-dev4 and RxMath. Rexx-tronics consumes its public optics, acoustics, electromechanics, thermal, fracture and 2-D free-surface surfaces; it does not copy those solver laws.

## ooRexx runtime

Qualified with Open Object Rexx 5.3.0 r13196 Internal Test Version from the user-supplied debug package.
