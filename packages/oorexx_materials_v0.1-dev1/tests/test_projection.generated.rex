w=.CommonMaterials~water20C
fm=.PhysicsMaterialProjection~fluid(w)
if fm~density<>w~value('DENSITY') then call fail 'fluid density'
cu=.CommonMaterials~copper
tm=.PhysicsMaterialProjection~thermal(cu)
if tm~specificHeatCapacity<>385 then call fail 'thermal copper'
am=.CommonMaterials~aluminium6061T6
mm=.PhysicsMaterialProjection~mechanical(am)
if mm~density<>2700 then call fail 'mechanical density'
g=.CommonMaterials~glass
om=.PhysicsMaterialProjection~optical(g)
if om~medium~refractiveIndex(550)<1.5 then call fail 'optical index'
say 'PASS Physics World material projections'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires "/mnt/data/oorexx_materials_v0.1-dev1/deps/oorexx_units_v0.1-dev4/rexx/Units.cls"
::requires "/mnt/data/workparts2/deps/rexxtronics_v0.1-dev15/deps/oorexx_maths_v0.8/rexx/Maths.cls"
::requires "/mnt/data/pw12x/oorexx_physics_world_v0.1-dev12/rexx/PhysicsWorld.cls"
::requires "/mnt/data/pw12x/oorexx_physics_world_v0.1-dev12/rexx/Fluids.cls"
::requires "/mnt/data/pw12x/oorexx_physics_world_v0.1-dev12/rexx/Thermal.cls"
::requires "/mnt/data/pw12x/oorexx_physics_world_v0.1-dev12/rexx/Deformable.cls"
::requires "/mnt/data/oorexx_materials_v0.1-dev1/src/MaterialsCatalog.cls"
