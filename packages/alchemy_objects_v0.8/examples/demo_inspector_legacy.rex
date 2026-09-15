#!/usr/bin/env rexx
/* Demo runner for InspectorClouseau.cls
 *
 * ooRexx directive instructions must live in the directive section.
 * Keep executable code first; ::REQUIRES and ::CLASS directives follow.
 */

app = .DemoApplication~new
examiner = .InspectorClouseau~new
examiner~enableProbes(.true)

/* Dynamic rules.  These are examples, not hard-coded behaviour. */
examiner~dontFollowPackage("REXX")
examiner~reportQueueItems(.true)
examiner~reportCollectionSizes(.true)
examiner~reportCollectionItems(.true)
examiner~reportInheritanceMap(.true)
examiner~reportVariable("*")
examiner~suppressInternalClassMethods(.true)
examiner~suppressMethodOutput("__INSPECTOR_CLOUSEAU*")
examiner~suppressObjectOutputForPath("root:.environment*")
examiner~reportParentSourceTrailOnMethod("DEMOAGENT", "POLL", "*", "POLLAGENT", "NAME", "oracle", "inspector-clouseau-agent-poll-trail")
examiner~createInspectionReportOnSignal("DEMOAGENT", "POLLFAIL", "POLLFAILSIGNAL", "NAME", "oracle", "inspector-clouseau-agent-signal")
examiner~createInspectionReportOnSignal("DEMOAGENT", "POLLSYNTAXFAIL", "SYNTAX", "NAME", "oracle", "inspector-clouseau-agent-syntax")
examiner~createInspectionReportOnProcedureSignal("DEMOHELPER", "HELPERSIGNAL", "inspector-clouseau-procedure-signal")
examiner~collectTraceOnMethod("DEMOENGINE", "DISPATCH", .nil, .nil, "inspector-clouseau-dispatch-trace")

examiner~attach(app)
snapshot = examiner~snapshot
say snapshot~asText
snapshot~writeJson("inspector-clouseau-demo.json")
snapshot~writeText("inspector-clouseau-demo.txt")

say "Triggering DemoEngine::dispatch; this should create inspector-clouseau-dispatch-trace-1.json/.txt with TraceObject evidence"
dispatchEvent = app~engine~dispatch
say "Dispatch event class:" dispatchEvent~class~id

say "Triggering DemoAgent::poll through DemoEngine::pollAgent; this should create inspector-clouseau-agent-poll-trail-2.json/.txt"
result = app~engine~pollAgent("oracle")
say "Poll result class:" result~class~id

say "Triggering DemoAgent::pollFail; this should create inspector-clouseau-agent-signal-3.json/.txt when POLLFAILSIGNAL is reached"
result = app~engine~pollAgentSignal("oracle")
say "Signal poll result class:" result~class~id

say "Triggering DemoAgent::pollSyntaxFail; this should create inspector-clouseau-agent-syntax-4.json/.txt with RC/SIGL/CONDITION('O') evidence"
result = app~engine~pollAgentSyntax("oracle")
say "Syntax poll result class:" result~class~id
exit 0

::requires "InspectorClouseau.cls"

::class DemoApplication public
::attribute engine

::method init
  expose engine
  engine = .DemoEngine~new


::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope = "OBJECT"
  self~setMethod(probeName, source, scope)
  return .true

::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class DemoEngine public
::attribute agents
::attribute dispatchQueue

::method init
  expose agents dispatchQueue
  agents = .directory~new
  dispatchQueue = .queue~new
  oracle = .DemoAgent~new("oracle")
  agents~put(oracle, "oracle")
  dispatchQueue~queue(.DemoPollEvent~new("oracle"))

::method dispatch
  expose dispatchQueue
  signal on syntax name dispatchSyntax
  if dispatchQueue~items > 0 then return dispatchQueue~peek
  return .nil

dispatchSyntax:
  return .nil

::method pollAgent
  expose agents
  use strict arg agentName
  agent = agents~at(agentName)
  return agent~poll

::method pollAgentSignal
  expose agents
  use strict arg agentName
  agent = agents~at(agentName)
  return agent~pollFail

::method pollAgentSyntax
  expose agents
  use strict arg agentName
  agent = agents~at(agentName)
  return agent~pollSyntaxFail


::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope = "OBJECT"
  self~setMethod(probeName, source, scope)
  return .true

::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class DemoAgent public
::attribute name
::attribute inbox
::attribute outbox

::method init
  expose name inbox outbox
  use strict arg name
  inbox = .queue~new
  outbox = .queue~new

::method poll
  expose outbox
  signal on syntax name pollSyntax
  outbox~queue(.DemoPollResult~new("ok"))
  return outbox~peek

pollSyntax:
  return .nil

::method pollFail
  expose name
  signal pollFailSignal
  return .nil

pollFailSignal:
  return .DemoPollResult~new("signal")

::method pollSyntaxFail
  expose name
  signal on syntax name pollSyntaxTrap
  __icWillFail = 10 / 0
  return .nil

pollSyntaxTrap:
  return .DemoPollResult~new("syntax")


::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope = "OBJECT"
  self~setMethod(probeName, source, scope)
  return .true

::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class DemoPollEvent public
::attribute agent
::method init
  expose agent
  use strict arg agent


::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope = "OBJECT"
  self~setMethod(probeName, source, scope)
  return .true

::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class DemoPollResult public
::attribute status
::method init
  expose status
  use strict arg status

::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope = "OBJECT"
  self~setMethod(probeName, source, scope)
  return .true

::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::routine demoHelper public
  signal helperSignal
  return "not reached"

helperSignal:
  return "handled"
