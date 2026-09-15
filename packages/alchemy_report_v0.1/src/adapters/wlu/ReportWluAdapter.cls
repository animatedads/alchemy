/******************************************************************************/
/* WLU evidence for Alchemy Report.                                           */
/* WLU is work, not money. Price-book quotes are DERIVED bindings only.       */
/* This file does not ::requires WorkLoadUnits.cls.                           */
/******************************************************************************/
::class ReportWluReservationAdapter public subclass ReportAdapterBase

::method transformId class
  return "wlu.reservation/0.12"

::method bind class
  use arg bindingId, role, d
  self~need(d, "reservationId")
  point = "WLU:RESERVE:" || d["reservationId"]
  span = self~opt(d, "span", "")
  if span = "" then do
     exp = self~opt(d, "expectedMicroWlu", "")
     rate = self~opt(d, "rateMicroWluPerSecond", "")
     bits = ""
     if exp \= "" then bits = "expectedMicroWlu=" || exp
     if rate \= "" then bits = bits || " rate=" || rate
     span = bits~strip
  end
  return .ReportBinding~new(bindingId, role, "WLU_RESERVATION", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportWluSettlementAdapter public subclass ReportAdapterBase

::method transformId class
  return "wlu.settlement/0.12"

::method bind class
  use arg bindingId, role, d
  self~need(d, "settlementId")
  point = "WLU:SETTLE:" || d["settlementId"]
  span = self~opt(d, "span", "")
  if span = "" then do
     act = self~opt(d, "actualMicroWlu", "")
     if act \= "" then span = "actualMicroWlu=" || act
  end
  return .ReportBinding~new(bindingId, role, "WLU_SETTLEMENT", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportWluNodeAdapter public subclass ReportAdapterBase

::method transformId class
  return "wlu.hierarchy.node/0.12"

::method bind class
  use arg bindingId, role, d
  self~need(d, "nodePath")
  point = "WLU:NODE:" || d["nodePath"]
  span = self~opt(d, "span", "")
  if span = "" then do
     ceil = self~opt(d, "ceilingMicroWlu", "")
     if ceil \= "" then span = "ceilingMicroWlu=" || ceil
  end
  return .ReportBinding~new(bindingId, role, "WLU_HIERARCHY_NODE", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportWluPriceBookAdapter public subclass ReportAdapterBase
/* Money is a translation of settled WLU. Bind as DERIVED, never PRIMARY fact. */

::method transformId class
  return "wlu.pricebook.quote/0.12"

::method bind class
  use arg bindingId, role, d
  self~need(d, "priceBookId")
  self~need(d, "version")
  point = "WLU:PRICEBOOK:" || d["priceBookId"] || ":" || d["version"]
  span = self~opt(d, "span", "")
  if span = "" then do
     cur = self~opt(d, "currency", "")
     amt = self~opt(d, "microCurrency", "")
     if cur \= "" then span = cur || " " || amt
  end
  if role~upper = "PRIMARY" then
     raise syntax 40.900 array("price-book quote must not be PRIMARY; WLU is work")
  return .ReportBinding~new(bindingId, role, "WLU_PRICE_BOOK", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "FINANCIAL"))


::class ReportWluHierarchyRule public
/* Same settled work is reflected at every ancestor. It is not multiplied. */
::method reflectedWork class
  use arg actualMicroWlu, nodeCount
  numeric digits 20
  if \datatype(actualMicroWlu, "N") | \datatype(nodeCount, "W") then
     raise syntax 40.900 array("WLU reflected work needs numeric actual and whole nodeCount")
  if nodeCount < 1 then
     raise syntax 40.900 array("nodeCount must be >= 1")
  r = .directory~new
  r["actualMicroWlu"] = actualMicroWlu
  r["nodeCount"] = nodeCount
  r["additiveWrong"] = actualMicroWlu * nodeCount
  r["accountedMicroWlu"] = actualMicroWlu
  return r

::requires "../ReportAdapterBase.cls"
