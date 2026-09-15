e=.AJIAccountingTestSupport~accountingEngine
.AJITestSupport~assert(e~legalEntityId=.AllJapanInsuranceBuild~LEGAL_ENTITY_ID,"AJI legal entity book")
ids=e~book~chart~accountIds
do id over ids
  account=e~book~chart~get(id)
  .AJITestSupport~assert(account~currencyMode="SINGLE","AJI monetary account single currency " || id)
  .AJITestSupport~assert(account~accountCurrency="JPY","AJI monetary account JPY " || id)
end
payload=.directory~new
payload["currency"]="GBP"; payload["amountMinor"]=100
bad=.AccountingEvent~new("AJI:COLLECTION:GBP","ALL_JAPAN_INSURANCE_CO_LTD","PREMIUM_COLLECTED","2026-08-28","","","TEST",payload)
r=e~transact(bad)
.AJITestSupport~assert(\r~ok,"foreign-currency collection does not silently enter JPY book")
.AJITestSupport~assert(r~errorCode="AJI_ACCOUNTING_FUNCTIONAL_CURRENCY_MISMATCH","explicit FX policy required")
say "PASS AJI accounting book is legal-entity isolated and JPY-only"
::requires "AccountingTestSupport.cls"
