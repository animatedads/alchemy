/******************************************************************************/
/* Host / PSS / AS400 record points. Transform id is caller-supplied;         */
/* FlyLo pnr.status/1 is not assumed.                                         */
/******************************************************************************/
::class ReportHostRecordAdapter public subclass ReportAdapterBase

::method bind class
  use arg bindingId, role, d
  self~need(d, "recordPoint")
  xf = self~opt(d, "transformId", "")
  return .ReportBinding~new(bindingId, role, "HOST_RECORD", d["recordPoint"],,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), xf,,
        self~opt(d, "privacyClass", "OPERATIONAL"))

::requires "../ReportAdapterBase.cls"
