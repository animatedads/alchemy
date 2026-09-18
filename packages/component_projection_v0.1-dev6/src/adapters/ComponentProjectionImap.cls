/* Optional IMAP adapter for component.projection/0.1.
 * Observation only. It does not issue IMAP commands and therefore cannot
 * mutate server or mailbox state simply by being mounted/projected. */
::class ComponentProjectionImapBuild public
::constant VERSION "0.1-dev1"
::constant API "component.projection.imap/0.1"

::class ImapComponentProjectionSource subclass ComponentProjectionSource public
::method init
  expose session
  use strict arg sessionArg
  if sessionArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_SESSION_REQUIRED")
  session=sessionArg
::method read
  expose session
  use strict arg keyArg
  if \keyArg~isA(.Array) | keyArg~items<2 then raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_KEY_INVALID")
  scope=keyArg[1]~string; field=keyArg[2]~string
  if scope="session" then do
    select
      when field="state" then return session~state
      when field="greeting" then return session~greeting
      when field="capabilities" then return session~capabilities
      when field="last_event_error" then return session~lastEventError
      otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_FIELD_INVALID",field)
    end
  end
  if scope="selected" then do
    s=session~selectedState
    if s==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_NO_SELECTED_MAILBOX")
    select
      when field="mailbox" then return s~mailbox
      when field="exists" then return s~exists
      when field="recent" then return s~recent
      when field="unseen_count" then return s~unseenCount
      when field="first_unseen_sequence" then return s~firstUnseenSequence
      when field="uid_validity" then return s~uidValidity
      when field="uid_next" then return s~uidNext
      when field="highest_modseq" then return s~highestModSeq
      when field="read_only" then return s~readOnly
      when field="flags" then return s~flags
      when field="permanent_flags" then return s~permanentFlags
      otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_FIELD_INVALID",field)
    end
  end
  raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_KEY_INVALID")

::class ImapComponentProjectionAdapter public
::method init
  expose registry session root componentName source selectedInstalled
  use strict arg registryArg,sessionArg,rootArg="/imap",componentArg="IMAP"
  if registryArg==.nil | sessionArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_IMAP_ARGUMENT_REQUIRED")
  registry=registryArg; session=sessionArg; root=.ComponentProjectionPath~normalize(rootArg); componentName=componentArg~string
  source=.ImapComponentProjectionSource~new(session); selectedInstalled=.false
::method install
  expose root
  self~report(root||"/session/state",.array~of("session","state"),"IMAP session state")
  self~report(root||"/session/greeting",.array~of("session","greeting"),"Server greeting object","application/x-oorexx-object")
  self~report(root||"/session/capabilities",.array~of("session","capabilities"),"Negotiated IMAP capabilities","application/x-oorexx-object")
  self~report(root||"/session/last_event_error",.array~of("session","last_event_error"),"Most recent diagnostic sink error")
  return self~refresh
::method refresh
  expose registry session root componentName selectedInstalled
  if session~selectedState==.nil then do
    if selectedInstalled then registry~unregisterTree(root||"/selected",componentName)
    selectedInstalled=.false
    return 0
  end
  if \selectedInstalled then do
    self~report(root||"/selected/mailbox",.array~of("selected","mailbox"),"Selected mailbox")
    self~report(root||"/selected/exists",.array~of("selected","exists"),"Selected mailbox EXISTS count")
    self~report(root||"/selected/recent",.array~of("selected","recent"),"Selected mailbox RECENT count")
    self~report(root||"/selected/unseen_count",.array~of("selected","unseen_count"),"Selected mailbox UNSEEN count")
    self~report(root||"/selected/first_unseen_sequence",.array~of("selected","first_unseen_sequence"),"First unseen sequence")
    self~report(root||"/selected/uid_validity",.array~of("selected","uid_validity"),"UIDVALIDITY")
    self~report(root||"/selected/uid_next",.array~of("selected","uid_next"),"UIDNEXT")
    self~report(root||"/selected/highest_modseq",.array~of("selected","highest_modseq"),"HIGHESTMODSEQ")
    self~report(root||"/selected/read_only",.array~of("selected","read_only"),"Selected mailbox read-only flag")
    self~report(root||"/selected/flags",.array~of("selected","flags"),"Advertised flags")
    self~report(root||"/selected/permanent_flags",.array~of("selected","permanent_flags"),"Permanent flags")
  end
  selectedInstalled=.true
  return 1
::method uninstall
  expose registry root componentName selectedInstalled
  n=registry~unregisterTree(root,componentName); selectedInstalled=.false; return n
::method report private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,mediaTypeArg="text/plain"
  if registry~endpoint(pathArg)==.nil then registry~registerReport(componentName,pathArg,source,keyArg,mediaTypeArg,descriptionArg)
  return .true
::requires "ComponentProjection.cls"
