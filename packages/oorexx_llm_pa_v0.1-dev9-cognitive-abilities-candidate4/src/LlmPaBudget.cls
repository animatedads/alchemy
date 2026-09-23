/* External PA work budget. WLU controls admission; the accounting rate is
 * deliberately separate and only translates settled work into money. */

::class LlmPaExternalBudgetPolicy public
::attribute budgetMicroDollars get
::attribute hourlyMicroWlu get
::attribute accountingMicroDollarsPerWlu get

::method init
  expose budgetMicroDollars hourlyMicroWlu accountingMicroDollarsPerWlu
  use arg hourlyWluArg, accountingRateArg, budgetArg = 30000
  hourlyMicroWlu = hourlyWluArg * 1000000
  accountingMicroDollarsPerWlu = accountingRateArg
  budgetMicroDollars = budgetArg
  if \datatype(hourlyWluArg, "W") | hourlyWluArg < 1 then raise syntax 88.900 array("PA hourly WLU ceiling must be a positive whole number")
  if \datatype(accountingRateArg, "W") | accountingRateArg < 0 then raise syntax 88.900 array("PA accounting rate must be a non-negative whole number")
  if \datatype(budgetMicroDollars, "W") | budgetMicroDollars < 1 then raise syntax 88.900 array("PA dollar budget must be positive microdollars")
  if self~costFor(hourlyMicroWlu) > budgetMicroDollars then raise syntax 88.900 array("PA WLU ceiling exceeds the hourly dollar policy")

::method costFor
  expose accountingMicroDollarsPerWlu
  use arg microWlu
  return .WLUUnits~ceilDivide(microWlu * accountingMicroDollarsPerWlu, 1000000)

::method safeDescription
  expose budgetMicroDollars hourlyMicroWlu accountingMicroDollarsPerWlu
  d = .directory~new
  d["budget_microdollars"] = budgetMicroDollars
  d["hourly_micro_wlu"] = hourlyMicroWlu
  d["accounting_microdollars_per_wlu"] = accountingMicroDollarsPerWlu
  d["wlu_is_money"] = .false
  return d

::requires "LlmPaCore.cls"
::requires "WorkLoadUnits.cls"
