/******************************************************************************/
/* oorexx_logging evidence. Not the logger.                                   */
/******************************************************************************/
::class ReportLogAdapter public subclass ReportAdapterBase

::method transformId class
  return "logging.event/0.7"

::method bind class
  use arg bindingId, role, d
  self~need(d, "eventId")
  point = "LOG:" || d["eventId"]
  span = self~opt(d, "span", "")
  if span = "" then do
     lvl = self~opt(d, "level", "")
     logger = self~opt(d, "logger", "")
     span = (lvl || " " || logger)~strip
  end
  return .ReportBinding~new(bindingId, role, "LOG_EVENT", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "INTERNAL"))

::requires "../ReportAdapterBase.cls"
