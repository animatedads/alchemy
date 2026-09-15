/******************************************************************************/
/* Accounting evidence — journal / GL / period.                               */
/* Not aviation, not collateral. Books only.                                  */
/******************************************************************************/
::class ReportJournalAdapter public subclass ReportAdapterBase

::method transformId class
  return "accounting.journal.entry/0.1"

::method bind class
  use arg bindingId, role, d
  self~need(d, "entryId")
  point = "ACCT:JOURNAL:" || d["entryId"]
  return .ReportBinding~new(bindingId, role, "JOURNAL_ENTRY", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "FINANCIAL"))


::class ReportGlPostingAdapter public subclass ReportAdapterBase

::method transformId class
  return "accounting.gl.posting/0.1"

::method bind class
  use arg bindingId, role, d
  self~need(d, "postingId")
  self~need(d, "account")
  point = "ACCT:GL:" || d["account"] || ":" || d["postingId"]
  span = self~opt(d, "span", "")
  if span = "" then do
     side = self~opt(d, "side", "")
     amt  = self~opt(d, "amount", "")
     if side \= "" then span = side || " " || amt
  end
  return .ReportBinding~new(bindingId, role, "GL_POSTING", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "FINANCIAL"))


::class ReportPeriodAdapter public subclass ReportAdapterBase

::method transformId class
  return "accounting.period.close/0.1"

::method bind class
  use arg bindingId, role, d
  self~need(d, "book")
  self~need(d, "period")
  point = "ACCT:PERIOD:" || d["book"] || ":" || d["period"]
  return .ReportBinding~new(bindingId, role, "ACCOUNTING_PERIOD", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "FINANCIAL"))


::class ReportJournalBalance public
/* Directories with side + amount. Balanced iff DR total = CR total. */
::method check class
  use arg postings
  numeric digits 20
  dr = 0
  cr = 0
  do i = 1 to postings~items
     d = postings[i]
     side = d["side"]~string~upper
     amt = d["amount"]
     if \datatype(amt, "N") then
        raise syntax 40.900 array("non-numeric posting amount")
     if side = "DR" | side = "DEBIT" then dr = dr + amt
     else if side = "CR" | side = "CREDIT" then cr = cr + amt
     else raise syntax 40.900 array("posting side must be DR or CR")
  end
  r = .directory~new
  r["debit"] = dr
  r["credit"] = cr
  r["balanced"] = (dr = cr)
  r["difference"] = dr - cr
  return r

::requires "../ReportAdapterBase.cls"
