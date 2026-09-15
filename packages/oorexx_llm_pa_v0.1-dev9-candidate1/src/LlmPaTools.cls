/* Controlled PA function surface. First concrete function: read_calendar.
 * Functions expose capability metadata separately from model prose so future
 * tool-broker integration can preserve read/mutate/eventability boundaries.
 */

::class LlmPaReadCalendarTool public
::attribute name get
::attribute accessMode get
::attribute eventable get
::attribute mutating get

::method init
  expose reminders name accessMode eventable mutating
  use arg remindersArg
  if remindersArg == .nil then raise syntax 88.900 array("read_calendar requires reminder service")
  reminders = remindersArg
  name = "read_calendar"
  accessMode = "READ_ONLY"
  eventable = .true
  mutating = .false

::method invoke public
  expose reminders
  return reminders~calendar

::requires "LlmPaReminder.cls"
