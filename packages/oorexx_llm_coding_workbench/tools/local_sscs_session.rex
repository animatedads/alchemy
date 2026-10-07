/*
 * Persistent local SSCS session.
 * Protocol is line oriented and hex encodes arbitrary text payloads.
 * No website, HTTP listener, or MCP HTTPS server is involved.
 */
parse arg dbRoot memberPath
if strip(dbRoot) = '' then do
  say 'ERROR|MISSING_DBROOT'
  exit 2
end
if strip(memberPath) = '' then memberPath = 'demo/workbench.rex'

store = .SemanticSourceStore~new(dbRoot)
authority = .SemanticSourceMcpDirect~new(store~sql)
desk = .SemanticSourceDevelopmentDesk~new(authority)

say 'READY|LOCAL_SSCS_SESSION|BACKEND|' || store~backendId || '|SCHEMA|' || store~SCHEMA_VERSION
call lineout

do forever
  wire = linein()
  if wire = 'QUIT' then leave
  parse var wire verb '|' payload
  verb = verb~upper

  select
    when verb = 'PING' then say 'OK|PING'
    when verb = 'BUTTONS' then do
      do b over desk~buttons
        say 'BUTTON|' || b['action'] || '|' || c2x(b['label']) || '|' || c2x(b['purpose'])
      end
    end
    when verb = 'VIEW_CLASS' then do
      className = x2c(payload)
      r=.directory~new; r['class_name']=className
      d=desk~press('VIEW_CLASS',r)
      if d['class']==.nil then say 'NOT_FOUND|CLASS'
      else do
        say 'CLASS|' || c2x(className)
        do a over d['attributes']; say 'ATTRIBUTE|' || c2x(a['source_spelling']); end
        do m over d['methods']; say 'METHOD|' || c2x(m['source_spelling']); end
      end
    end
    when verb = 'VIEW_METHOD' then do
      decoded=x2c(payload); parse var decoded className '09'x methodName
      r=.directory~new; r['class_name']=className; r['method_name']=methodName
      d=desk~press('VIEW_METHOD',r)
      if d==.nil then say 'NOT_FOUND|METHOD'
      else do
        say 'METHOD|' || c2x(d['source_spelling'])
        say 'SOURCE|' || c2x(d['source_text'])
      end
    end
    when verb = 'WRITE_METHOD' then do
      decoded=x2c(payload)
      parse var decoded className '09'x methodName '09'x body
      r=selfRequest(memberPath)
      r['class_name']=className; r['method_name']=methodName; r['method_body']=body
      d=desk~press('WRITE_METHOD',r)
      say 'OK|WRITE_METHOD|' || c2x(className) || '|' || c2x(methodName) || '|' || receiptRevision(d)
    end
    when verb = 'MATERIALISE' then do
      r=.directory~new
      r['package_object_id']='oorexx://package/' || memberPath
      r['project_id']='default'
      d=desk~press('MATERIALISE',r)
      say 'SOURCE|' || c2x(d~files[memberPath])
    end
    otherwise say 'ERROR|UNKNOWN_VERB|' || verb
  end
  say 'END'
  call lineout
end
exit 0

selfRequest: procedure
  parse arg path
  r=.directory~new
  r['package_object_id']='oorexx://package/' || path
  r['member_path']=path
  actor=value('SSCS_ACTOR',,'ENVIRONMENT')
  if strip(actor)='' then actor='llm-coding-workbench'
  r['actor']=actor
  return r

receiptRevision: procedure
  use arg d
  if d==.nil then return ''
  if d~hasIndex('revision_id') then return d['revision_id']
  return ''

::requires 'SemanticSourceStore.cls'
::requires 'SemanticSourceMcpDirect.cls'
::requires 'SemanticSourceDevelopmentDesk.cls'
