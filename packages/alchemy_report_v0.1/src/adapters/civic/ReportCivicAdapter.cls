/******************************************************************************/
/* CivicPort documents. Optional for any app that retains civic evidence.     */
/******************************************************************************/
::class ReportCivicAdapter public subclass ReportAdapterBase

::method transformId class
  return "civic.json.mapping/0.2"

::method bind class
  use arg bindingId, role, d
  self~need(d, "documentId")
  point = "CIVIC:" || d["documentId"]
  return .ReportBinding~new(bindingId, role, "CIVIC_DOCUMENT", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "UNKNOWN"))

::requires "../ReportAdapterBase.cls"
