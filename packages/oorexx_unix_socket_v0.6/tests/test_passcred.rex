numeric digits 50
pair = .UnixSocket~socketPair('SOCK_DGRAM')
if pair == .nil then do; say 'FAIL socketPair'; exit 1; end

receiver = pair[2]
sender = pair[1]
if receiver~setPassCredentials(.true) \= 0 then call fail receiver, 'setPassCredentials'
if receiver~passCredentials \== .true then do; say 'FAIL SO_PASSCRED state'; exit 1; end

payload = 'credential-message'
if sender~send(payload) \= payload~length then call fail sender, 'send'
message = receiver~recvMessage(256, 0)
if message == .nil then call fail receiver, 'recvMessage credentials'
if message~data \== payload then do; say 'FAIL credential payload'; exit 1; end
if \message~hasCredentials then do; say 'FAIL no SCM_CREDENTIALS received'; exit 1; end
cred = message~credentials
peer = receiver~peerCredentials
if peer == .nil then call fail receiver, 'peerCredentials'
if cred~at('PID') \= peer~at('PID') | cred~at('UID') \= peer~at('UID') | cred~at('GID') \= peer~at('GID') then do
  say 'FAIL SCM_CREDENTIALS does not match kernel SO_PEERCRED'
  exit 1
end

/* Verify credentials and SCM_RIGHTS can arrive in one recvmsg without one
   ancillary record hiding or truncating the other. */
resource = .UnixSocket~socketPair('SOCK_STREAM')
if resource == .nil then do; say 'FAIL resource socketPair'; exit 1; end
fds = .array~of(resource[1]~fd)
if sender~sendDescriptors('C', fds) \= 1 then call fail sender, 'sendDescriptors with passcred'
combined = receiver~recvDescriptors(64, 4)
if combined == .nil then call fail receiver, 'recvDescriptors with passcred'
if combined~descriptors~items \= 1 | \combined~hasCredentials then do
  say 'FAIL combined SCM_RIGHTS/SCM_CREDENTIALS result'
  exit 1
end
combined~descriptors[1]~close
resource[1]~close
resource[2]~close

if receiver~setPassCredentials(.false) \= 0 then call fail receiver, 'clear SO_PASSCRED'
if receiver~passCredentials \== .false then do; say 'FAIL SO_PASSCRED clear state'; exit 1; end
sender~close
receiver~close
say 'PASS kernel per-message SCM_CREDENTIALS and combined ancillary receive'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
