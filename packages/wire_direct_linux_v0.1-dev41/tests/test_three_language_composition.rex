/* One Wire identity, three language roles, one process.
 * ooRexx owns selection/live state; JavaScript receives a bounded row projection;
 * Prolog receives the same retained live ooRexx Mail object. */
parse arg rules
if rules == '' then do; say 'rules path required'; exit 2; end

js=.AlchemyJavaScriptQuickJSRuntime~new(.true,"",128,1024,1000)
prolog=.AlchemyPrologRuntime~new
engine=prolog~engine
q=engine~query('user','consult',.array~of(prolog~atom(rules)))
call assertTrue 'consult', q~nextSolution

mail=.WireQualificationMail~new(prolog,'INBOX|4242|8738','boss@example.com','FYI')
/* ooRexx application selection owns the object and stable identity. */
selected=mail
call assertEqual 'oorexx-selected-identity',selected~stableId,'INBOX|4242|8738'

/* JS sees only the bounded projection deliberately made for this filter. */
call assertEqual 'javascript-before', jsAccept(js,selected), .false

/* Mutate the live ooRexx application object between language operations. */
selected~subject='ACTION REQUIRED'
call assertEqual 'identity-after-mutation',selected~stableId,'INBOX|4242|8738'
call assertEqual 'javascript-after', jsAccept(js,selected), .true

/* Prolog gets that same live Rexx object, not the JS projection or a DTO. */
q2=engine~query('wire_mail_rules','needs_attention',.array~of(prolog~rexxObject(selected)))
call assertTrue 'prolog-after-live-mutation', q2~nextSolution
call assertEqual 'identity-after-prolog',selected~stableId,'INBOX|4242|8738'

say 'wire-three-language-composition=PASS identity='selected~stableId 'jsEngine='js~engineInfo 'prologVersion='prolog~version
exit 0

jsAccept: procedure
  use strict arg runtime,mail
  id=mail~identity
  sender=mail~sender
  subject=mail~subject
  source='(function(){const row={identity:'id',from:' || jsQuote(sender) || ',subject:' || jsQuote(subject) || '}; return row.from === "boss@example.com" && row.subject === "ACTION REQUIRED";})()'
  return runtime~evaluate(source)

jsQuote: procedure
  use strict arg s
  s=s~changestr('\\','\\\\')~changestr('"','\\"')
  return '"'s'"'

assertTrue: procedure
  use strict arg label,value
  if value \== .true then do; say label'=FAIL got='value; exit 1; end
  return
assertEqual: procedure
  use strict arg label,got,expected
  if got \== expected then do; say label'=FAIL got='got 'expected='expected; exit 1; end
  return

::class WireQualificationMail public
::method init
  expose prologRuntime stableId sender subject
  use strict arg prologRuntime,stableId,sender,subject
::attribute stableId get
::attribute sender
::attribute subject
::method identity
  expose stableId
  parse var stableId . '|' . '|' n
  return n
::method senderForProlog
  expose prologRuntime sender
  return prologRuntime~callbackAtom(sender)
::method subjectForProlog
  expose prologRuntime subject
  return prologRuntime~callbackAtom(subject)

::requires 'AlchemyJavaScriptQuickJSRuntime.cls'
::requires 'AlchemyProlog.cls'
