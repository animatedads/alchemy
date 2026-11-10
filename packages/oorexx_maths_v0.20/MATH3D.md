# 3D mathematics — ooRexx Maths v0.8

v0.8 adds provider-neutral geometry, rotation, transform, camera and projection mathematics. These are Maths objects, not OpenGL objects. Graphics/API adapters may choose memory layout and upload conventions, but the mathematical core retains explicit semantic conventions.

## Public object family

- `.MathAngle`
- `.MathVector3`
- `.MathVector4`
- `.MathMatrix3`
- `.MathMatrix4`
- `.MathQuaternion`
- `.Math3DConvention`
- `.MathTransform3D`
- `.MathAffineTransform3D`
- `.MathProjection`
- `.MathPerspective`
- `.MathOrthographic`
- `.MathRay3D`
- `.MathPlane3D`

## Core convention

Maths v0.8 uses **column-vector algebra**. Therefore:

```rexx
model = T * R * S
point2 = model * point
```

applies `S` first, then `R`, then `T`.

Matrix storage order is not mathematical meaning. `.MathMatrix4` can export either row-major or column-major flattened arrays:

```rexx
m~toRowMajorArray
m~toColumnMajorArray
```

This lets a graphics adapter obtain the layout it needs without redefining the transform.

## Explicit graphics conventions

Projection objects require a `.Math3DConvention`. Supplied constructors are:

```rexx
.Math3DConvention~openGL   /* RH, NDC z [-1,+1], column vectors */
.Math3DConvention~vulkan   /* RH, NDC z [0,+1], column vectors  */
.Math3DConvention~directX  /* LH, NDC z [0,+1], column vectors  */
```

Handedness, depth range and vector convention are retained in the object and evidence path. No class silently assumes that a generic 4x4 matrix is an OpenGL matrix.

## Quaternion surface

```rexx
axis = .MathVector3~new(0,0,1,ctx)
angle = .MathAngle~degrees(90,ctx)
q = .MathQuaternion~fromAxisAngle(axis,angle,ctx)

rotated = q * .MathVector3~new(1,0,0,ctx)
/* [0,1,0] within the declared numerical context */

identity = q * q~inverse
m3 = q~toMatrix3
```

Quaternion multiplication is Hamilton multiplication and order is significant. Axis-angle construction normalizes the axis. Conjugation and inversion establish working precision before unary negation or division.

## Transforms

```rexx
T = .MathTransform3D~translation(1,2,3,ctx)
R = .MathTransform3D~rotation(q,ctx)
S = .MathTransform3D~scale(2,2,2,ctx)
model = T * R * S

point2 = model * point
vector2 = model~transformDirection(vector)
back = model~inverse * point2
```

Points use homogeneous `w=1`. Directions use `w=0`, so translation does not affect them. A general point transform performs perspective division when output `w` differs from one.

`MathTransform3D~inverse` delegates to the ordinary Maths matrix solver rather than carrying a second 3D-specific inversion algorithm.

## Camera/view transform

```rexx
view = .MathTransform3D~lookAt(eye,target,up,ctx,convention)
```

The orthonormal basis is constructed according to the convention's handedness. Right-handed/OpenGL views look down negative Z; left-handed/DirectX views look down positive Z.

## Perspective

```rexx
p = .MathPerspective~new( -
      .MathAngle~degrees(60,ctx), -
      aspect, near, far, ctx, -
      .Math3DConvention~openGL)
```

The evidence path retains FOV, aspect, near/far planes, handedness, NDC depth range and vector convention.

Qualification includes:

- OpenGL near plane -> NDC `-1`, far -> `+1`;
- Vulkan near -> `0`, far -> `+1`;
- DirectX left-handed near -> `0`, far -> `+1`.

## Orthographic projection

`.MathOrthographic` implements the same explicit handedness/depth-range contract and is tested at near/far and boundary corners.

## Exact-domain boundary

3D algebra that is rational remains exact when a rational context is selected:

```rexx
v = .MathVector3~new(3,4,0,.MathContext~rational)
say v~norm               /* exact MathInteger 5 */
```

Cross products, dot products, translation and scale can likewise remain exact where their inputs permit it.

Maths does **not** pretend irrational/transcendental results are rational. For example, `sqrt(2)` or `sin(90 deg)` in a `RATIONAL` context fails closed. The caller must select a decimal/binary context for operations involving irrational roots, pi or trigonometric functions.

## Evidence

3D results retain operation paths using the same `.MathEvidence` / `.MathPathStep` framework as the rest of Maths. Examples include:

- `quaternion.fromAxisAngle`
- `quaternion.multiply`
- `quaternion.conjugate`
- `quaternion.rotateVector`
- `quaternion.toMatrix3`
- `transform3d.compose`
- `transform3d.inverse`
- `transform3d.lookAt`
- `projection.perspective`
- `projection.orthographic`

These paths describe the mathematical construction. They do not assert graphics-driver or GPU execution semantics.
