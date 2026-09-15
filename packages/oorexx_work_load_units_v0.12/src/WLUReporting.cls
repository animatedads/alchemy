/*
 * WLUReporting v0.1
 *
 * Reporting deliberately sits downstream of WLU accounting.  Work is
 * accounted in stable WLU first.  A versioned price book may then translate
 * settled WLU into money without changing admission or metering semantics.
 */

::options digits 30

/* Optional finance translation classes.  These are intentionally outside
 * WorkLoadUnits.cls: WLU admission and scheduling never depend on currency. */

::class WLUMoneyQuote public
::attribute currency get
::attribute microCurrency get
::attribute priceBookId get
::attribute priceBookVersion get
::attribute microWlu get

::method init
  expose currency microCurrency priceBookId priceBookVersion microWlu
  use strict arg currency, microCurrency, priceBookId, priceBookVersion, microWlu

::class WLUPriceBook public
::attribute priceBookId get
::attribute version get
::attribute currency get
::attribute microCurrencyPerWlu get

::method init
  expose priceBookId version currency microCurrencyPerWlu
  use strict arg priceBookId, version, currency, microCurrencyPerWlu
  priceBookId = priceBookId~string~strip
  version = version~string~strip
  currency = currency~string~strip~upper
  if priceBookId = "" | version = "" | currency = "" then raise syntax 88.900 array("WLU price book id, version and currency must not be empty")
  if \datatype(microCurrencyPerWlu, "W") | microCurrencyPerWlu < 0 then raise syntax 88.900 array("WLU price must be non-negative integer micro-currency per WLU")

::method price
  expose priceBookId version currency microCurrencyPerWlu
  use strict arg microWlu
  numeric digits 30
  ignore = .WLUUnits~assertMicro(microWlu)
  amount = .WLUUnits~ceilDivide(microWlu * microCurrencyPerWlu, .WLUDBuild~MICRO_PER_WLU)
  return .WLUMoneyQuote~new(currency, amount, priceBookId, version, microWlu)

::class WLUBillingStatement public
::attribute accountId get
::attribute fromTick get
::attribute throughTick get
::attribute settledMicroWlu get
::attribute currency get
::attribute microCurrency get
::attribute priceBookId get
::attribute priceBookVersion get
::attribute settlementCount get

::method init
  expose accountId fromTick throughTick settledMicroWlu currency microCurrency priceBookId priceBookVersion settlementCount
  use strict arg accountId, fromTick, throughTick, settledMicroWlu, currency, microCurrency, priceBookId, priceBookVersion, settlementCount

::class WLUBillingCalculator public

::method statement class
  use strict arg events, accountId, priceBook, fromTick = 0, throughTick = .nil
  numeric digits 30
  accountId = accountId~string~strip
  if accountId = "" then return .WLUResult~failure("WLU_BILLING_ACCOUNT_REQUIRED", "account id must not be empty")
  if priceBook == .nil | \priceBook~isA(.WLUPriceBook) then return .WLUResult~failure("WLU_PRICE_BOOK_REQUIRED", "billing requires a WLUPriceBook")
  if \datatype(fromTick, "W") | fromTick < 0 then return .WLUResult~failure("WLU_BILLING_WINDOW_INVALID", "fromTick must be non-negative")
  if throughTick \== .nil then do
    if \datatype(throughTick, "W") | throughTick < fromTick then return .WLUResult~failure("WLU_BILLING_WINDOW_INVALID", "throughTick must be >= fromTick")
  end

  total = 0
  count = 0
  lastTick = fromTick
  do event over events
    if event == .nil | \event~isA(.WLULedgerEvent) then return .WLUResult~failure("WLU_BILLING_EVENT_INVALID", "statement accepts WLULedgerEvent objects only")
    if event~accountId \= accountId then iterate
    if event~tick < fromTick then iterate
    if throughTick \== .nil then if event~tick > throughTick then iterate
    type = event~eventType~upper
    /* These are terminal accounting states.  RESERVE, CONSUME and TOPUP are
     * evidence but must not be billed again or the ledger would double-count. */
    if type \= "SETTLED" & type \= "RELEASED" & type \= "EXPIRED" then iterate
    total += event~microWlu
    count += 1
    if event~tick > lastTick then lastTick = event~tick
  end

  money = priceBook~price(total)
  if throughTick == .nil then throughTick = lastTick
  statement = .WLUBillingStatement~new(accountId, fromTick, throughTick, total, money~currency, money~microCurrency, money~priceBookId, money~priceBookVersion, count)
  return .WLUResult~success(statement)

::requires "WorkLoadUnits.cls"
