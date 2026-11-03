/* F11RearExterior.cls
 * Authoritative rear exterior/stairwell geometry supplied 2026-09-29.
 * Coordinate convention follows the accepted F11 plan: X right, Y down, Z up.
 * The back of the property is Y=0; exterior rear space is negative Y.
 */

::class F11RearExteriorGeometry public
::constant REAR_PROPERTY_Y 0.0
::constant REAR_STEP_Y -4.0
::constant LOWER_GROUND_Z 0.0
::constant REAR_STEP_TOP_Z 1.5
::constant STAIR_OPENING_BOTTOM_Z 0.0
::constant STAIR_OPENING_TOP_Z 2.0
::constant PROPERTY_FLOOR_Z 3.0
::constant STAIR_X_MIN 5.499107375
::constant STAIR_X_MAX 6.997316195
::constant STAIR_FRONT_Y 3.847672652
::constant STAIR_OPENING_CENTER_X 6.248211785
::constant STAIR_OPENING_WIDTH 1.0
::constant PROPERTY_REAR_X_MIN 0.017025100
::constant PROPERTY_REAR_X_MAX 20.004492773

::method apertureXMin class
    return self~STAIR_OPENING_CENTER_X - self~STAIR_OPENING_WIDTH / 2

::method apertureXMax class
    return self~STAIR_OPENING_CENTER_X + self~STAIR_OPENING_WIDTH / 2

/* Add only surfaces whose geometry is now authoritative.  The paved lower
 * ground plane and negligible edge ramps are retained in geometry metadata but
 * are not invented as reflection materials here. */
::method addToSolver class
    use strict arg solver, stairMaterial, frequencies, context
    hard = .AcousticSpectralMaterial~rigid(frequencies)
    count = 0

    /* Strong hard reflector formed by the 1.5 m terrain step, 4 m behind the
     * rear property plane.  Its X span follows the accepted property width. */
    a = .MathVector3~new(self~PROPERTY_REAR_X_MIN, self~REAR_STEP_Y, self~LOWER_GROUND_Z, context)
    b = .MathVector3~new(self~PROPERTY_REAR_X_MAX, self~REAR_STEP_Y, self~LOWER_GROUND_Z, context)
    solver~addSurface(.AcousticSpectralSurface~new("REAR_TERRAIN_STEP", -
        .AcousticVerticalPanel~new(a, b, self~LOWER_GROUND_Z, self~REAR_STEP_TOP_Z), hard))
    count += 1

    /* Lower stairwell shaft walls.  Existing F11 room geometry starts at the
     * property floor (z=3 m); these panels extend the stairwell down to the
     * excavated ground level without sealing the 1 m x 2 m rear aperture. */
    count += self~addPanel(solver, "STAIRWELL_LOWER_LEFT", -
        self~STAIR_X_MIN, self~REAR_PROPERTY_Y, self~STAIR_X_MIN, self~STAIR_FRONT_Y, -
        self~LOWER_GROUND_Z, self~PROPERTY_FLOOR_Z, stairMaterial, context)
    count += self~addPanel(solver, "STAIRWELL_LOWER_RIGHT", -
        self~STAIR_X_MAX, self~REAR_PROPERTY_Y, self~STAIR_X_MAX, self~STAIR_FRONT_Y, -
        self~LOWER_GROUND_Z, self~PROPERTY_FLOOR_Z, stairMaterial, context)
    count += self~addPanel(solver, "STAIRWELL_LOWER_FRONT", -
        self~STAIR_X_MIN, self~STAIR_FRONT_Y, self~STAIR_X_MAX, self~STAIR_FRONT_Y, -
        self~LOWER_GROUND_Z, self~PROPERTY_FLOOR_Z, stairMaterial, context)

    /* Rear wall around the actual opening: two jambs from z=0..2 and one
     * lintel from z=2..3.  The omitted centre span is the acoustic aperture. */
    count += self~addPanel(solver, "STAIRWELL_REAR_JAMB_LEFT", -
        self~STAIR_X_MIN, self~REAR_PROPERTY_Y, self~apertureXMin, self~REAR_PROPERTY_Y, -
        self~STAIR_OPENING_BOTTOM_Z, self~STAIR_OPENING_TOP_Z, stairMaterial, context)
    count += self~addPanel(solver, "STAIRWELL_REAR_JAMB_RIGHT", -
        self~apertureXMax, self~REAR_PROPERTY_Y, self~STAIR_X_MAX, self~REAR_PROPERTY_Y, -
        self~STAIR_OPENING_BOTTOM_Z, self~STAIR_OPENING_TOP_Z, stairMaterial, context)
    count += self~addPanel(solver, "STAIRWELL_REAR_LINTEL", -
        self~STAIR_X_MIN, self~REAR_PROPERTY_Y, self~STAIR_X_MAX, self~REAR_PROPERTY_Y, -
        self~STAIR_OPENING_TOP_Z, self~PROPERTY_FLOOR_Z, stairMaterial, context)

    return count

::method addPanel class
    use strict arg solver, name, x1, y1, x2, y2, zMin, zMax, material, context
    a = .MathVector3~new(x1, y1, zMin, context)
    b = .MathVector3~new(x2, y2, zMin, context)
    solver~addSurface(.AcousticSpectralSurface~new(name, -
        .AcousticVerticalPanel~new(a, b, zMin, zMax), material))
    return 1

::requires 'AcousticImpulseResponse.cls'
