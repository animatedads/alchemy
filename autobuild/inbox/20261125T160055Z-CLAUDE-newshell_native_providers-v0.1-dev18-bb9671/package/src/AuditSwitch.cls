/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted host operator only.
   Log-before-mutation through an injected logging service. */
::requires 'POSIXProvider.cls'
::requires 'LoggingCore.cls'
::class AuditSwitch public
::method init
  expose provider service scope
  use strict arg provider,service,scope
::method run
  expose provider service scope
  use strict arg action
  action=action~lower
  if \.Array~of('status','on','off')~hasItem(action) then raise syntax 93.900 array ('Use status, on or off')
  before=provider~auditStatus
  self~printStatus('BEFORE',before)
  log=service~loggerFor(self,'RUN',.Array~of(action),scope)
  req=.Directory~new; req['KIND']='AUDIT_CONTROL_REQUEST'; req['ACTION']=action; req['STATUS']=before~copy
  accepted=log~log(.Log~INFO,req,'BODY')
  out=.Directory~new; out['OK']=.false; out['ATTEMPTED']=.false; out['LOGGED_BEFORE']=accepted
  if \accepted then out['REASON']='request logging unavailable'
  else if \before['OK'] then out['REASON']='status unavailable'
  else if action=='status' then do; out['OK']=.true; out['REASON']='status'; end
  else if before['ENABLED']=2 then out['REASON']='audit locked; refused'
  else do
    out['ATTEMPTED']=.true
    flag=(action=='on')
    changed=provider~auditSetEnabled(flag)
    out['OK']=changed['OK']; out['REASON']=changed['ERROR']
  end
  after=provider~auditStatus
  self~printStatus('AFTER',after)
  if \after['OK'] then out['OK']=.false
  else if out['ATTEMPTED'] then if after['ENABLED']\=flag then out['OK']=.false
  out['BEFORE']=before; out['AFTER']=after
  rec=.Directory~new; rec['KIND']='AUDIT_CONTROL_RESULT'; rec['ACTION']=action; rec['OK']=out['OK']; rec['ATTEMPTED']=out['ATTEMPTED']; rec['REASON']=out['REASON']; rec['STATUS']=after~copy
  out['LOGGED_AFTER']=log~log(.Log~INFO,rec,'BODY')
  if \out['LOGGED_AFTER'] then do
    out['OK']=.false; out['REASON']='result logging failed; inspect actual after status'
  end
  return out
::method printStatus private
  use strict arg phase,r
  if r['OK'] then say phase 'enabled='r['ENABLED'] 'failure='r['FAILURE'] 'pid='r['PID'] 'backlog_limit='r['BACKLOG_LIMIT'] 'lost='r['LOST'] 'backlog='r['BACKLOG']
  else say phase 'status unavailable errno='r['ERRNO'] r['ERROR']
