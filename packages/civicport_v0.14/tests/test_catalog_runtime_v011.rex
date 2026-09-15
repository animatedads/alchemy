catalog = .CivicSourceCatalog~defaultCatalog
postcode = .CivicPostcodeApiContract~new
company = .CivicCompanyApiContract~new
companySandbox = .CivicCompanySandboxApiContract~new
metar = .CivicMetarApiContract~new

call checkContract catalog, "postcodes.io.postcode", postcode
call checkContract catalog, "companieshouse.company-profile", company
call checkContract catalog, "companieshouse.company-profile.sandbox", companySandbox
call checkContract catalog, "aviationweather.metar", metar
say "PASS test_catalog_runtime_v011"
exit 0

checkContract: procedure
  use arg catalog, sourceId, contract
  mapping = catalog~resolveExact(sourceId, contract~mappingGeneration)
  call assertTrue mapping~ok, sourceId || " Runtime mapping generation exists in source catalogue"
  descriptor = mapping~descriptor
  call assertEqual contract~abilityId, descriptor~abilityId, sourceId || " Runtime ability id agrees with catalogue"
  call assertEqual contract~contractGeneration, descriptor~contractGeneration, sourceId || " Runtime contract generation agrees with catalogue"
  reverse = catalog~resolveAbility(contract~abilityId, contract~contractGeneration)
  call assertTrue reverse~ok, sourceId || " Runtime ability reverse lookup succeeds"
  call assertEqual sourceId, reverse~descriptor~sourceId, sourceId || " Runtime ability reverse lookup stays on same source"
  return

::requires "TestSupport.cls"
::requires "CivicCatalog.cls"
::requires "CivicRuntime.cls"
::requires "CivicCompaniesHouseRuntime.cls"
::requires "CivicAviationWeatherRuntime.cls"
