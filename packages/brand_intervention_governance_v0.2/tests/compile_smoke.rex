r=.BrandInterventionGovernanceRuleSet~new; r~seal
call assertEqual '0.2',.BrandInterventionGovernanceBuild~VERSION,'version'
call assertTrue r~isA(.AlchemyObject),'rules are AlchemyObject'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionGovernance.cls'
