parse arg port
hop=.SmtpNextHop~new('127.0.0.1',port,'client.test',.false)
env=.SmtpEnvelope~new('<alice@example.test>'); env~addRecipient('<bob@example.test>')
msg=.SmtpMessage~new(env,'From: alice@example.test'||'0d0a'x||'To: bob@example.test'||'0d0a'x||'0d0a'x||'body'||'0d0a'x)
t=.RxSockStartTlsSmtpRelayTransport~new(.nil)
r=t~deliver(hop,msg,env~recipients)
say 'QUIT_REPRO ok='||r~ok||' code='||r~code||' detail='||r~detail
if r~ok then do
  d=r~value~recipientResults['<bob@example.test>']
  say 'recipient state='||d['state']||' code='||d['code']
end
::requires 'src/SmtpOutboundDispatcher.cls'
