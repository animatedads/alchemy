policy = .LlmPaExternalBudgetPolicy~new(3, 10000)
if policy~budgetMicroDollars \= 30000 then exit 1
if policy~hourlyMicroWlu \= 3000000 then exit 2
if policy~costFor(3000000) \= 30000 then exit 3
if policy~safeDescription["wlu_is_money"] then exit 4
say "PASS test_budget_policy"
exit 0
::requires "LlmPaBudget.cls"
