/* Application behaviour: deliberately renderer- and protocol-neutral. */
::class MailBehaviour public
::method init
  expose ui sources
  use arg ui, sources

::method showMessage
  expose ui sources
  use arg event
  message = sources["imap"]~message(event~context["identity"])
  ui~byId("message")~value = message
