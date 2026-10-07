/* Explicit Rexx-native projection boundary for the LLM Coding Workbench.
 *
 * The workbench carries live Rexx objects internally.  This adapter is the
 * deliberate point at which those objects are projected for an external
 * JSON/API/logging boundary.  Projection is therefore visible, testable and
 * replaceable rather than scattered through orchestration code.
 */
::class LlmCodingBoundaryAdapter public

::method turnDirectory
  use strict arg turn
  if turn==.nil then raise syntax 88.900 array("coding turn is required")
  if \turn~hasMethod("ASDIRECTORY") then -
    raise syntax 88.900 array("coding turn does not provide asDirectory")
  projected=turn~asDirectory
  if \projected~isA(.directory) then -
    raise syntax 88.900 array("coding turn projection must be a Directory")
  return projected

::method turnJson
  use strict arg turn
  return .json~toJson(self~turnDirectory(turn))

::method traceSummary
  use strict arg event
  if event==.nil then raise syntax 88.900 array("trace event is required")
  if \event~hasMethod("ASSUMMARY") then -
    raise syntax 88.900 array("trace event does not provide asSummary")
  return event~asSummary

::method traceSummaries
  use strict arg instrumentation
  if instrumentation==.nil then raise syntax 88.900 array("instrumentation object is required")
  if \instrumentation~hasMethod("SUMMARIES") then -
    raise syntax 88.900 array("instrumentation does not provide summaries")
  return instrumentation~summaries

::requires "json.cls"
