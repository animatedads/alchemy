# Source provenance — ooRexx Physics World v0.1-dev10

## Immediate baseline

Dev9 is based directly on generated Physics World v0.1-dev8:

- `oorexx_physics_world_v0.1-dev8.zip`
- SHA-256 `08f6a7c40b27c8b0612df7e5e8ec5def8369725a0379e4aaec9aea5610121c07`

Dev8 itself is based on the user-supplied dev7 tree and introduced reciprocal electromechanical transduction. Dev9 retains that code and all earlier optics, mechanics, deformable, fluids, free-surface and acoustic behavior, then adds continuous driven radiation and thermal state.

## External authorities retained

- user-supplied ooRexx Maths v0.8 — SHA-256 `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`;
- user-supplied ooRexx Units v0.1-dev4 — SHA-256 `b0916df3d8b68f1681f219e0e8770e490a6f7c00165cc5959b84d14354d4fa46`;
- ooRexx 5.3.0 r13196 remains the qualification runtime baseline.

## Dev9-authored work

Dev9 adds:

- `rexx/DrivenAcoustics.cls`;
- `rexx/Thermal.cls`;
- continuous actual-mechanics radiating-patch history and retarded pressure rendering;
- lumped thermal nodes, explicit heat-power evidence, conduction, convection and radiation;
- focused qualification fixtures and two examples;
- documentation/manifest/validation updates.

No Python physics solver is part of the delivered package. Physics continues to consume, not fork, Maths and Units.


## Dev10 merge provenance

Dev10 is based directly on the user-supplied current Physics authority:

- `oorexx_physics_world_v0.1-dev9(1).zip`
- SHA-256 `89b83dee9fda3566291ac41b4a097db1ce3afbc318c3daf47762b346b8c0e5bd`

That dev9 tree is retained for optics, rigid/deformable mechanics, contact, acoustics, driven acoustics, thermal, electromechanics, fluid foundations, one-axis free-surface behavior and vessel dynamics. Dev10 merges only the parallel two-axis slosh work into that authority:

- `rexx/FreeSurfaceFluids2D.cls`;
- `examples/sloshing_tank_2d.rex`;
- five focused `test_free_surface_2d_*.rex` fixtures;
- documentation, manifest and validation updates.

The source of those files is the previously generated parallel Physics slosh branch `oorexx_physics_world_v0.1-dev9.zip` (SHA-256 `954658888862b27bba47dd4e68568da41961cfafcd959966a2b30532a98909e9`). No existing dev9 Physics source module was replaced to perform the merge.


## dev11
Derived directly from the reconciled Physics World v0.1-dev10.1 authority (SHA-256 `936737a18d2c96a627e86d322b3dbf6bda06134a2410fc7eafb58c750cf6cc3c`). Adds fracture-aware fluid containment while retaining Maths v0.8 and Units v0.1-dev4 as external authorities.


## dev12
Derived directly from Physics World v0.1-dev11 (SHA-256 `5a06eeec80396c655ecafbbb341858ec5a1801139098036349ca29ef299f9478`). Adds conservative external escaped-fluid parcel mechanics; Maths v0.8 and Units v0.1-dev4 remain external authorities.


## dev13
Derived directly from Physics World v0.1-dev12 (SHA-256 `0227307d965d62122e49133197e04e4153b05da57b61897970f4cb02f2d1f627`). The uploaded Parts v0.1-dev1 package was inspected for boundary context only; dev13 does not copy or absorb the parts catalogue. Maths v0.8 and Units v0.1-dev4 remain external authorities.


## dev14
Derived directly from Physics World v0.1-dev13 (`b89f63ab949e2928c23f9a48b3989949909a94f7fe23355dff404d4cc509f6c1`). Peer context inspected: Physical Manufacturing v0.1-dev2 (`1af458dd513efbe3dd65d35efc942215a46c9a1e7cd7a59412870acc58104177`), Materials v0.1-dev1 (`0e6f327f9ed1837dbfca7c5563e40f290ea5bac89972d08df229cf5613c85587`), Parts v0.1-dev2 (`938e9ecfeb8a9ba5fc727ad6239d88127c4c524045b5387426f3c889737f31d2`). They are peer authorities and are not embedded.


## dev15
Derived from Physics World v0.1-dev14 (`7a8b966890073ed4017310c16b7621fa3a7ab78d87018e18fd6dfe78540bc9c8`). This increment generalises internal observation infrastructure; it does not import game/crowd semantics or peer catalogue authority.


## dev16
Derived from Physics World v0.1-dev15 (`4a7edee5e07a42d6b9accf29eedb8a0724bb06ace2b2ebf5f7231b6aa798fd66`). Peer interfaces inspected: Parts v0.1-dev8 (`0d4135034067a4c037c1e5a81da28d03781c36e3ac679f4b90408669af0887f2`) including `SportsBallProjection`, and Materials v0.1-dev4 (`adbf99e1cfc21d12e06ea03eba1d4f05e331f3d28f04c3a4583aedf20392feea`). Neither peer catalogue is embedded.


## dev17
Derived from Physics World v0.1-dev16 (`d6c31e80cb34e1fbfa83c332d14a7fec25d848b2ad2683b892c29bbf56d22a87`). Current peer baselines supplied for continuity are Parts v0.1-dev10 and Materials v0.1-dev5; no peer catalogue source is embedded in Physics.

## dev18
Derived from Physics World v0.1-dev17. Propulsion and tyre laws introduced here are explicit reduced-order/provider boundaries. `LinearStaticThrustMap`, `ConstantRollingResistance`, and `EnergyProportionalWearLaw` are reference/calibration implementations, not asserted universal aircraft data.

## dev19
Derived from Physics World v0.1-dev18 SHA-256 `25d22a86cb894ca28e427c0399e274392d240dd326a0c0a5f1d3525b1fd54659`. Library review on 2026-09-24 found a current Flylo integration refresh and unrelated newer reusable packages; no newer authoritative Physics landing-gear implementation was found and none was copied into this package. Landing dynamics remain a Physics-owned reduced-order capability.

## dev20
Derived from Physics World v0.1-dev19 SHA-256 `3dce2130bc778461ed2f313ad9e9d7f25251bfb5b851df4dbbf2b60ae947368c`. The aircraft-ground experiment composes existing Physics landing/tyre authority and does not import Flylo business rules.

## dev21
Derived from Physics World v0.1-dev20 SHA-256 `46848e9362d49c3a96ec229c262b685e4aa222d98046e32dc968fd5645f8752e`. The longitudinal equilibrium implementation uses explicit supplied geometry, mass, acceleration and gravity; it contains no aircraft-specific load-share constants.

## dev22
Derived from Physics World v0.1-dev21 SHA-256 `6cf9fb8c7c6f248c216cac682b485bd0781472abc3a838139a11e907f6c12c81`.
Library peers inspected 2026-09-24:
- Parts v0.1-dev11 SHA-256 `7261ab6e91480b58123d889468008b967d4f60f21500b3ae314b4a5f420e54cb`
- Materials v0.1-dev6 SHA-256 `aec12dcfedd9ff9581552eb9240d510806daf0b9a2857ea996d4cb34192e901a`
Parts dev11 primarily aligns rugby projection with Physics dev16 and repairs/generalises existing engineering catalogue families. Materials dev6 adds ceramic dielectric, HSS, carbide and spring-steel references. Neither peer supplies aircraft landing-gear/tyre/jet-engine catalogue authority, so dev22 does not manufacture such data.

## dev23
Derived from Physics World v0.1-dev22 SHA-256 `ae3c06e268f31f2a276a028c2db0f728628d666348fda317db5725639eb7c487`.
A broad Library refresh on 2026-09-24 identified newer reusable packages including Migratable Job v0.2.6, Physical Manufacturing v0.1-dev5, Storage Fabric v0.1-dev23, Vision/video adapters, Wire UI Windows and Wire3D. These are peer capabilities, not implicit Physics dependencies. Existing Parts v0.1-dev11 and Materials v0.1-dev6 remain the latest named Parts/Materials archives observed in the Library listing.

## dev24
Derived from Physics World v0.1-dev23 SHA-256 `f71920e433c079082d64e3206477a099b6f03e4dd9c260758cbb7ef49a3ab22d`.
Library inspection found `oorexx_parts_azure_bulk_delivery_20260924.zip` SHA-256 `bda7c57eaa3012ba23a249f49f4e5fcd61beb86f1c2a793be72dd6640eb41380`. Its research factory contains 93 bulk candidates: 10 each fasteners/bearings/shafts/gears/springs/resistors/capacitors/diodes/connectors and 3 structural-stock candidates. This package does not promote those research candidates to aerodynamic or certified part truth.

## dev25
Derived from Physics World v0.1-dev24 SHA-256 `17a7a0656dafd8625a3f6ca8caf6ee75b2ef0620e76e8aa596675a2a4df1445c`.
The Library was refreshed before this increment; dev24 remains the latest Physics package and the 2026-09-24 Azure bulk Parts delivery remains the latest Parts-related delivery observed. No research-factory candidate was promoted into aerodynamic coefficient authority.

## dev26
Derived from Physics World v0.1-dev25 SHA-256 `489992506ff6c3472154d21a5e6ea972f7a2f69c21b9a5e0c649d85a65c3ac83`.
Library was refreshed before implementation; dev25 remained the latest Physics artifact and no newer Parts/aerodynamics package had appeared beyond the previously inspected Azure bulk Parts delivery.

## dev27
Derived from Physics World v0.1-dev26 SHA-256 `145a1621f6a31e4f06d20f0003087278ebb5661290f74bdf0b7093b2ffee1e2b`.
Library refresh found new Maths v0.9 and `PHYSICS_NUMERICS.md`; Maths v0.9 explicitly factors reusable high-precision scalar mathematics, 1-D/2-D interpolation, sampled-series/spectral maths, quadratics and linear-system wrappers from patterns observed in Physics dev26 while retaining physical equations/semantics in Physics. dev27 qualification therefore uses Maths v0.9 as peer dependency. New Wire3D dev29.9 Physics-world integration was also observed but is a renderer/consumer, not Physics authority.

## dev28
Derived from Physics World v0.1-dev27 SHA-256 `875ed75c149bddb8ca7e0dec1f6056be9fde4017c6405705710ff6394307a120`.
The user-supplied `harmonic_slosh_lateral_demo.rex` was inspected directly. Its hand-written combination of dev27 static roll moment with `FreeSurfaceFluids2D` reaction torque is promoted here into a reusable Physics composition object; its illustrative crowd forcing and tank assumptions are not promoted as authoritative physical constants.

## dev29
Derived from Physics World v0.1-dev28 SHA-256 `68aafc2b489e9f5249b186c85200584589bd6b4f22f2d14c4ce1ce5908ffd5f5`.
The CFL diagnostic was added in response to the explicit shallow-water shoaling hypothesis raised while analysing the user-supplied harmonic slosh demo. The implementation instruments the existing solver equations and makes no new empirical fluid constant or unqualified physical assumption.

## dev30
Derived from Physics World v0.1-dev29 SHA-256 `abcec91ba246ce4b701ac172d34a2a8cff465b0f04fe6ecb1ee18e724354bf8a`.
The freeze architecture borrows the proven design principle from the separate MVS/KL10 emulator work—future-determining continuation state must be explicit and reloadable—but shares no emulator code and creates no emulator dependency. Physics owns its own checkpoint schemas and participant contracts.

## dev31
Derived from Physics World v0.1-dev30 SHA-256 `7a082ea357c676f146b4084399bb4d3909ed7948d6c5f84233f15231fb6b2a42`.
The acoustic oracle is a general Physics capability prompted by the F11/FC/FD experiment but contains no F11 room identity, target delay, event label or localisation score.
The live journal adapter consumes the user-supplied `oorexx_journal_pointed_state_v0.1` public contract rather than defining a Physics-private journal.

## dev38
Continues from Library head `oorexx_physics_world_v0.1-dev37-f11-moving-reflector.zip`. Dev37 already corrected the moving-car case to finite bistatic/diffuse scattering because the elevated F11 source/receivers cannot physically mirror-reflect through the 1.5 m vehicle side in that geometry. Dev38 preserves that distinction and extends only the reusable early-arrival path families.

## dev39
Continues from Physics World v0.1-dev38. The guitar seam was designed against Library `oorexx_guitar_tab_audio_v0.1-dev1.zip` and `rexxtronics_v0.1-dev22.zip`. The standalone demo's reduced-order `MagneticPickupModel` is not imported as Physics authority; dev39 instead terminates at an evidence-bearing magnetic-flux observation so Rexx-tronics can apply its existing `GuitarMagneticPickup` Faraday law.

## dev40
Continues from runtime-qualified Physics World v0.1-dev39.1 and Library Rexx-tronics v0.1-dev22. The guitar structural model remains Physics-owned; no pickup winding, electrical network or Audio inference has been moved into Physics.

## dev41
Continues from runtime-qualified Physics World v0.1-dev40. The reciprocal boundary is Physics-owned mechanical state; Rexx-tronics remains authoritative for pickup/circuit state and Audio remains an independent observation/analysis consumer.

## dev44
Continues from Physics World dev43 and consumes the user-supplied sealed Maths v0.10 archive (SHA-256 `52e48b7000be2808b1171fc61b4e6deb208641a57ea479a68713b055f5db1cb9`). Physics uses the public Maths operation surface rather than NumPy directly.

## dev44.1 native runtime qualification
Foreign Runtime v0.22.6 was recovered from Library (`oorexx_foreign_runtime_v0.22.6(8).zip`, SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`). Runtime qualification used the user-supplied ooRexx 5.3.0 r13196 debug Debian package and NumPy 2.3.5.

## dev45
Consumes user-supplied `oorexx_maths_v0.11(1).zip`, SHA-256 `c93cff916c07130a3d54af4db048e5d2a257a08e0405633dc2c9543e5a067a38`, and Library Foreign Runtime v0.22.6 for native SCIPY qualification. Continues from Physics World dev44.1.


## dev46.1 repair provenance

Base archive: user-supplied `oorexx_physics_world_v0.1-dev46(1).zip`. dev46.1 changes are limited to drum-kit mechanics/history/tests/docs: no unrelated Physics authority was moved.


## dev46.6 continuation provenance
Base: dev46.4 band-repair candidate. Numerical continuation/delay authority: user-supplied sealed `oorexx_maths_v0.14(1).zip`. Physics changes are limited to the guitar Maths projection, one regression, version/docs/manifest. No guitar topology or physical coupling constants are changed.
