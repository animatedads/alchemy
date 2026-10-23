#!/usr/bin/env rexx
say 'SIP/RTP INSTRUMENTATION CORRELATION PROBE START'

sipIdentity=.InstrumentationCodec~identity('alchemy','sip','sip-a','','','SIP')
rtpIdentity=.InstrumentationCodec~identity('alchemy','rtp','rtp-a','','','RTP')
sip=.SipInstrumentationSink~new(sipIdentity)
rtp=.RtpInstrumentationSink~new(rtpIdentity)

sipEvent=.Directory~new
sipEvent['schema']='oorexx.sip.event/1'
sipEvent['eventId']='sip-source-1'
sipEvent['eventSequence']=1
sipEvent['eventType']='SIP.CALL.CREATED'
sipEvent['component']='sip.server'
sipEvent['objectId']='sip-call-control-1'
sipEvent['callId']='call-42'
sip~recordEvent(sipEvent)

rtpEvent=.Directory~new
rtpEvent['schema']='oorexx.rtp.event/1'
rtpEvent['eventId']='rtp-source-1'
rtpEvent['eventSequence']=1
rtpEvent['eventType']='RTP.ENDPOINT.OPENED'
rtpEvent['component']='rtp.endpoint'
rtpEvent['objectId']='rtp-endpoint-1'
rtpEvent['callId']='call-42'
rtp~recordEvent(rtpEvent)

allEvents=.Array~new
allEvents~append(sip~events[1])
allEvents~append(rtp~events[1])
snapshots=.Array~new
publication=.InstrumentationCodec~publication('sip-rtp-pub','sip-rtp-probe',1,snapshots,'',.nil,.array~new,allEvents)
collector=.InstrumentationCollector~new(20)
receipt=collector~accept(publication)
call assertEq receipt['status'],'OK','publication accepted'
view=.InstrumentationCorrelationView~new(collector)
group=view~byId('call-42')
call assertTrue group<>.nil,'correlation group exists'
call assertEq group['event_count'],2,'SIP and RTP events grouped only by explicit call correlation'
call assertEq group['authorities']~items,2,'independent SIP/RTP authorities retained'
call assertTrue arrayHas(group['context_refs'],'sip-object:sip-call-control-1'),'SIP object context retained'
call assertTrue arrayHas(group['context_refs'],'rtp-object:rtp-endpoint-1'),'RTP object context retained'
call assertEq group['causation_edges']~items,0,'causation not inferred'

say 'PASS explicit cross-authority SIP/RTP correlation without ownership or inferred causation'
exit 0

arrayHas: procedure
  use arg values,wanted
  do value over values
    if value=wanted then return .true
  end
  return .false

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::requires 'sip_instrumentation.cls'
::requires 'rtp_instrumentation.cls'
::requires 'InstrumentationCorrelation.cls'