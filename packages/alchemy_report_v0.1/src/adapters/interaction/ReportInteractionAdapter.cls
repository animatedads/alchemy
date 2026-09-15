/******************************************************************************/
/* Interaction Event bindings. Brand/sass chains, not aviation.               */
/******************************************************************************/
::class ReportInteractionAdapter public subclass ReportAdapterBase

::method bind class
  use arg bindingId, role, d
  self~need(d, "eventId")
  point = "INTERACTION_EVENT:" || d["eventId"]
  return .ReportBinding~new(bindingId, role, "INTERACTION_EVENT", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), "",,
        self~opt(d, "privacyClass", "INTERNAL"))

::requires "../ReportAdapterBase.cls"
