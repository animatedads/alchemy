# Changelog

## 0.1-dev7
- Adds a layered rugby-league ball PartDefinition.
- Ball explicitly references butyl bladder, polyester reinforcement, cover elastomer,
  valve elastomer and AIR-20C inflation gas from Materials v0.1-dev4.
- Adds `SportsBallProjection` for Physics-facing mass/shape/inflation authority.
- Deliberately requires Physics to provide orientation-dependent drag, lift and spin models;
  Parts does not pretend the ball is spherical or invent aerodynamic coefficients.
- Adds focused material-resolution and projection-boundary qualification.

## 0.1-dev6
- Assembly/interface model and manufactured-state projection.
