/******************************************************************************/
/* Aviation / FlyLo only. Merchant bank and insurance must not load this.     */
/******************************************************************************/
::class ReportNotamAdapter public subclass ReportAdapterBase

::method transformId class
  return "notam.projection/0.3"

::method bind class
  use arg bindingId, role, d
  self~need(d, "notamId")
  point = "NOTAM:" || d["notamId"]
  xf = self~opt(d, "transformId", self~transformId)
  return .ReportBinding~new(bindingId, role, "NOTAM_AIXM", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), xf, self~opt(d, "privacyClass", "OPERATIONAL"))

::requires "../ReportAdapterBase.cls"
