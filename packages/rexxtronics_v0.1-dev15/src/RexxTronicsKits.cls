/* Rexx-tronics executable reference-kit fixtures v0.1-dev15.
 *
 * The kit layer is intentionally thin: it builds ordinary Rexx-tronics
 * components and nets.  The project object is provenance plus a repeatable
 * construction recipe, not a second electrical model.
 */

::class KitProject public
::attribute kitId get
::attribute projectNumber get
::attribute title get
::attribute sourceReference get
::attribute circuit get

::method init
  expose kitId projectNumber title sourceReference circuit
  use strict arg kitIdArg, projectNumberArg, titleArg, sourceReferenceArg
  kitId = kitIdArg~string
  projectNumber = projectNumberArg + 0
  title = titleArg~string
  sourceReference = sourceReferenceArg~string
  circuit = .Circuit~new

::method solveDC
  expose circuit
  return circuit~solveDC


/* Maxitronix 500-in-1 Hardware Entry Course, Project 7: LIGHT TELEGRAPH.
 * Source fixture uses the documented 270-ohm resistor, LED, S1 key and
 * 3-volt supply.  Physical breadboard coordinate mapping is deliberately a
 * later board-layer concern; this fixture qualifies the electrical schematic.
 */
::class Maxitronix500Project007 subclass KitProject public
::attribute source get
::attribute resistor get
::attribute led get
::attribute key get

::method init
  expose source resistor led key
  self~init:super('MAXITRONIX-500-IN-1', 7, 'LIGHT TELEGRAPH', 'Hardware Entry Course / Project 7')

  c = self~circuit
  source = c~add(.DCVoltageSource~new('V2', '3 V'))
  resistor = c~add(.Resistor~new('R1', '270 Ohm'))
  led = c~add(.LED~new('LED1', '1.7 V', '10 Ohm', '0.5 mA'))
  key = c~add(.Switch~new('S1', .true))

  c~connectGround(source~negative)
  c~connect('VCC', .array~of(source~positive, resistor~pin('A')))
  c~connect('LED_ANODE', .array~of(resistor~pin('B'), led~anode))
  c~connect('RETURN', .array~of(led~cathode, key~pin('A')))
  c~connectGround(key~pin('B'))

::method press
  expose key
  key~close
  return self

::method release
  expose key
  key~open
  return self

::requires 'RexxTronicsDC.cls'

/* Maxitronix 500-in-1 Hardware Entry Course, Project 14: MEET THE
 * TRANSISTOR.  The manual supplies two polarity demonstrations.  These two
 * fixture classes reproduce Schematic-1 (PNP, +9/+6 V rails) and Schematic-2
 * (NPN, -9/-7.5 V rails) using the documented resistor and battery values.
 *
 * The BJT parameters below remain Rexx-tronics qualification parameters, not
 * claims about the unidentified historical transistors in the kit.  An exact
 * part-number definition can replace them without changing either circuit.
 */
::class Maxitronix500Project014PNP subclass KitProject public
::attribute supply6 get
::attribute supply3 get
::attribute baseResistor get
::attribute ledResistor get
::attribute transistor get
::attribute led get
::attribute key get

::method init
  expose supply6 supply3 baseResistor ledResistor transistor led key
  self~init:super('MAXITRONIX-500-IN-1', 14, 'MEET THE TRANSISTOR / PNP', 'Hardware Entry Course / Project 14 / Schematic-1')
  c = self~circuit
  supply6 = c~add(.DCVoltageSource~new('V4', '6 V'))
  supply3 = c~add(.DCVoltageSource~new('V6', '3 V'))
  baseResistor = c~add(.Resistor~new('R1', '12 kOhm'))
  ledResistor = c~add(.Resistor~new('R2', '470 Ohm'))
  transistor = c~add(.PNPTransistor~new('Q1', 100, '0.7 V', '100 Ohm', '0.2 V', '10 Ohm'))
  led = c~add(.LED~new('LED1', '1.7 V', '10 Ohm', '0.5 mA'))
  key = c~add(.Switch~new('S1', .false, 0.001, 1e18))

  c~connectGround(supply6~negative)
  c~connect('MID6', .array~of(supply6~positive, supply3~negative, baseResistor~pin('B')))
  c~connect('EMITTER9', .array~of(supply3~positive, transistor~emitter))
  c~connect('BASE', .array~of(transistor~base, key~pin('A')))
  c~connect('BASE_RETURN', .array~of(key~pin('B'), baseResistor~pin('A')))
  c~connect('COLLECTOR', .array~of(transistor~collector, led~anode))
  c~connect('LED_RETURN', .array~of(led~cathode, ledResistor~pin('A')))
  c~connectGround(ledResistor~pin('B'))

::method press
  expose key
  key~close
  return self

::method release
  expose key
  key~open
  return self


::class Maxitronix500Project014NPN subclass KitProject public
::attribute supply75 get
::attribute supply15 get
::attribute baseResistor get
::attribute ledResistor get
::attribute transistor get
::attribute led get
::attribute key get

::method init
  expose supply75 supply15 baseResistor ledResistor transistor led key
  self~init:super('MAXITRONIX-500-IN-1', 14, 'MEET THE TRANSISTOR / NPN', 'Hardware Entry Course / Project 14 / Schematic-2')
  c = self~circuit
  supply75 = c~add(.DCVoltageSource~new('V6', '7.5 V'))
  supply15 = c~add(.DCVoltageSource~new('V1', '1.5 V'))
  baseResistor = c~add(.Resistor~new('R3', '4.7 kOhm'))
  ledResistor = c~add(.Resistor~new('R4', '1 kOhm'))
  transistor = c~add(.NPNTransistor~new('Q2', 100, '0.7 V', '100 Ohm', '0.2 V', '10 Ohm'))
  led = c~add(.LED~new('LED1', '1.7 V', '10 Ohm', '0.5 mA'))
  key = c~add(.Switch~new('S1', .false, 0.001, 1e18))

  /* The manual's second schematic uses the bottom rail as the positive end of
   * the 7.5 V source, so MID is -7.5 V and the transistor emitter is -9 V.
   */
  c~connectGround(supply75~positive)
  c~connect('MID_MINUS7_5', .array~of(supply75~negative, supply15~positive, baseResistor~pin('B')))
  c~connect('EMITTER_MINUS9', .array~of(supply15~negative, transistor~emitter))
  c~connect('BASE', .array~of(transistor~base, key~pin('A')))
  c~connect('BASE_RETURN', .array~of(key~pin('B'), baseResistor~pin('A')))
  c~connect('COLLECTOR', .array~of(transistor~collector, led~cathode))
  c~connect('LED_ANODE', .array~of(led~anode, ledResistor~pin('A')))
  c~connectGround(ledResistor~pin('B'))

::method press
  expose key
  key~close
  return self

::method release
  expose key
  key~open
  return self

::requires 'RexxTronicsSemiconductors.cls'

/* Maxitronix 500-in-1 Hardware Entry Course, Project 15: TRANSISTORS AS
 * SWITCHES.  The manual ties all seven protected segment inputs to +9 V and
 * uses an NPN low-side switch on the common terminal so S1 displays an "8".
 * The manual states that protective resistors are built into the display but
 * does not give their value; 1 kOhm is therefore explicit qualification data,
 * not a historical-part claim.
 */
::class Maxitronix500Project015 subclass KitProject public
::attribute source get
::attribute baseResistor get
::attribute transistor get
::attribute display get
::attribute key get

::method init
  expose source baseResistor transistor display key
  self~init:super('MAXITRONIX-500-IN-1', 15, 'TRANSISTORS AS SWITCHES', 'Hardware Entry Course / Project 15')
  c = self~circuit
  source = c~add(.DCVoltageSource~new('V6', '9 V'))
  baseResistor = c~add(.Resistor~new('R1', '4.7 kOhm'))
  transistor = c~add(.NPNTransistor~new('Q1', 100, '0.7 V', '100 Ohm', '0.2 V', '10 Ohm'))
  display = c~add(.SevenSegmentDisplay~new('DISPLAY', 'COMMON_CATHODE', '1.7 V', '1 kOhm', '0.5 mA'))
  key = c~add(.Switch~new('S1', .false, 0.001, 1e18))

  c~connectGround(source~negative)
  c~connectGround(transistor~emitter)
  c~connect('DISPLAY_COM', .array~of(display~common, transistor~collector))
  c~connect('BASE', .array~of(baseResistor~pin('B'), transistor~base))
  c~connect('KEY_BASE', .array~of(key~pin('B'), baseResistor~pin('A')))

  high = .array~new
  high~append(source~positive)
  high~append(key~pin('A'))
  do seg over display~segmentNames
    high~append(display~segmentPin(seg))
  end
  c~connect('VCC9', high)

::method press
  expose key
  key~close
  return self

::method release
  expose key
  key~open
  return self

::requires 'RexxTronicsDisplays.cls'
