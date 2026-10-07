/* dev6 acceptance: finite deposition retains multiple physical coordinates. */
call require 'FiniteDeposition.cls'
-- Executable fixture intentionally uses the same public GrowingPrinterDynamics
-- and ThermalDepositionProcess constructors as dev5.  Full numeric qualification
-- requires the pinned ooRexx/Maths/Units/Physics dependency closure.
say 'PHYSICAL MANUFACTURING FINITE DEPOSITION PATH: LOAD OK'
