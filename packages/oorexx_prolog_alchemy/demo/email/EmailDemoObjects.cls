/* Minimal email object for a GTK/Wire demo.  Prolog sees the same live object. */
::class DemoEmail public
::method init
  expose runtime sender subject body
  use strict arg runtime, sender, subject, body = ""
::method senderForProlog
  expose runtime sender
  return runtime~callbackAtom(sender)
::method subjectForProlog
  expose runtime subject
  return runtime~callbackAtom(subject)
::method sender
  expose sender
  return sender
::method subject
  expose subject
  return subject
::method body
  expose body
  return body
