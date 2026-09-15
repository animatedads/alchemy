numeric digits 50
parse arg path payload
if path == '' then path = '/tmp/oorexx-credential-example.sock'
if payload == '' then payload = 'hello with kernel credentials'

sender = .UnixSocket~new('SOCK_DGRAM')
if sender~sendTo(payload, .UnixAddress~pathname(path)) \= payload~length then do
  say 'sendTo failed errno='sender~errno sender~errorText
  exit 1
end
sender~close
exit 0

::requires '../unixsocket.cls'
