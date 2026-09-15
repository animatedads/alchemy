/******************************************************************************/
/* Legal Effect traces — shared across apps that actually evaluate law.       */
/******************************************************************************/
::class ReportLegalTraceAdapter public subclass ReportAdapterBase

::method transformId class
  return "legal.effect/0.14"

::method bind class
  use arg bindingId, role, d
  self~need(d, "traceId")
  point = "LEGAL:trace:" || d["traceId"]
  return .ReportBinding~new(bindingId, role, "LEGAL_TRACE", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "LEGAL"))

::requires "../ReportAdapterBase.cls"
