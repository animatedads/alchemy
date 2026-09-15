say .BrandInteractionBuild~PRODUCT .BrandInteractionBuild~VERSION
p = .BrandInteractionPolicy~new
e = .BrandInteractionEngine~new
call assertTrue p~styleHighThreshold > 0, 'policy exists'
call assertTrue e~class == .BrandInteractionEngine, 'engine exists'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
