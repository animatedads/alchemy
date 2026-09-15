say .BrandInterventionEffectivenessBuild~PRODUCT .BrandInterventionEffectivenessBuild~VERSION
x=.BrandInterventionEffectivenessEngine~new
if x==.nil then exit 1
say 'PASS compile_smoke'
::requires 'BrandInterventionEffectiveness.cls'
