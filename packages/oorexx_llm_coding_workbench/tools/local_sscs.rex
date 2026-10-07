/*
 * Local Semantic Source Control runner.
 * One invocation == one in-process Development Desk semantic action.
 * No web server / HTTPS MCP endpoint is required.
 */
parse arg dbRoot action rest
if strip(dbRoot) = '' | strip(action) = '' then do
  say 'usage: rexx local_sscs.rex DBROOT ACTION [args...]'
  exit 2
end

store = .SemanticSourceStore~new(dbRoot)
action = action~upper

if action = 'BOOTSTRAP' then do
  store~bootstrap
  say 'OK|BOOTSTRAP|' || dbRoot
  exit 0
end

authority = .SemanticSourceMcpDirect~new(store~sql)
desk = .SemanticSourceDevelopmentDesk~new(authority)

select
  when action = 'PING' then do
    say 'OK|LOCAL_SSCS'
    say 'DBROOT|' || dbRoot
    say 'BACKEND|' || store~backendId
    say 'SCHEMA|' || store~SCHEMA_VERSION
  end
  when action = 'BUTTONS' then do
    do b over desk~buttons
      say b['action'] || '|' || b['label'] || '|' || b['purpose']
    end
  end
  when action = 'MODEL' then do
    m = desk~classFileModel
    say 'AUTHORITY|' || m['authority']
    say 'PROJECTION_RULE|' || m['projection_rule']
    do p over m['parts']
      say 'PART|' || p['kind'] || '|' || p['projection'] || '|' || p['comes_from']
    end
  end
  when action = 'CREATE_PACKAGE' then do
    parse var rest path
    if strip(path) = '' then do; say 'ERROR|MEMBER_PATH_REQUIRED'; exit 2; end
    r = .directory~new
    r['member_path'] = path
    r['actor'] = actorName()
    d = desk~press(action, r)
    say 'PACKAGE|' || d['package_object_id'] || '|' || d['member_path']
  end
  when action = 'ADD_REQUIRES' then do
    parse var rest path requiresTarget ordinal
    r = selfRequest(path)
    r['requires_target'] = requiresTarget
    r['ordinal'] = ordinal
    d = desk~press(action, r)
    say 'OK|REQUIRES|' || requiresTarget || '|' || receiptRevision(d)
  end
  when action = 'CREATE_CLASS' then do
    parse var rest path className ordinal
    r = selfRequest(path)
    r['class_name'] = className
    r['ordinal'] = ordinal
    d = desk~press(action, r)
    say 'OK|CLASS|' || className || '|' || receiptRevision(d)
  end
  when action = 'ADD_ATTRIBUTE' then do
    parse var rest path className attributeName ordinal
    r = selfRequest(path)
    r['class_name'] = className
    r['attribute_name'] = attributeName
    r['ordinal'] = ordinal
    d = desk~press(action, r)
    say 'OK|ATTRIBUTE|' || className || '|' || attributeName || '|' || receiptRevision(d)
  end
  when action = 'ADD_METHOD' then do
    parse var rest path className methodName ordinal
    r = selfRequest(path)
    r['class_name'] = className
    r['method_name'] = methodName
    r['ordinal'] = ordinal
    d = desk~press(action, r)
    say 'OK|METHOD|' || className || '|' || methodName || '|' || receiptRevision(d)
  end
  when action = 'LIST_CLASSES' then do
    parse var rest path
    r = .directory~new
    r['member_path'] = path
    rows = desk~press(action, r)
    do c over rows
      say 'CLASS|' || c['source_spelling']
    end
  end
  when action = 'WRITE_METHOD' then do
    parse var rest path className methodName bodyFile
    if strip(bodyFile) = '' then do; say 'ERROR|BODY_FILE_REQUIRED'; exit 2; end
    s = .stream~new(bodyFile)
    s~open('READ')
    body = s~charin(, s~chars)
    s~close
    r = selfRequest(path)
    r['class_name'] = className
    r['method_name'] = methodName
    r['method_body'] = body
    d = desk~press(action, r)
    say 'OK|METHOD_WRITTEN|' || className || '|' || methodName || '|' || receiptRevision(d)
  end
  when action = 'VIEW_CLASS' then do
    parse var rest className
    r = .directory~new
    r['class_name'] = className
    d = desk~press(action, r)
    c = d['class']
    if c == .nil then do; say 'NOT_FOUND'; exit 4; end
    say 'CLASS|' || className
    do a over d['attributes']; say 'ATTRIBUTE|' || a['source_spelling']; end
    do m over d['methods']; say 'METHOD|' || m['source_spelling']; end
  end
  when action = 'VIEW_METHOD' then do
    parse var rest className methodName
    r = .directory~new
    r['class_name'] = className
    r['method_name'] = methodName
    d = desk~press(action, r)
    if d == .nil then do; say 'NOT_FOUND'; exit 4; end
    say 'METHOD|' || d['source_spelling']
    say 'SOURCE_HEX|' || c2x(d['source_text'])
  end
  when action = 'VIEW_ATTRIBUTE' then do
    parse var rest className attributeName
    r = .directory~new
    r['class_name'] = className
    r['attribute_name'] = attributeName
    d = desk~press(action, r)
    if d == .nil then do; say 'NOT_FOUND'; exit 4; end
    say 'ATTRIBUTE|' || d['source_spelling']
    say 'SOURCE_HEX|' || c2x(d['source_text'])
  end
  when action = 'MATERIALISE' then do
    parse var rest path outPath
    if strip(path) = '' then do; say 'ERROR|MEMBER_PATH_REQUIRED'; exit 2; end
    r = .directory~new
    r['package_object_id'] = 'oorexx://package/' || path
    r['project_id'] = 'default'
    d = desk~press(action, r)
    text = d~files[path]
    if strip(outPath) = '' then say 'SOURCE_HEX|' || c2x(text)
    else do
      s = .stream~new(outPath)
      s~open('WRITE REPLACE')
      s~charout(text)
      s~close
      say 'OK|MATERIALISED|' || outPath || '|' || text~length
    end
  end
  otherwise do
    say 'UNKNOWN_ACTION|' || action
    exit 3
  end
end
exit 0

selfRequest: procedure
  parse arg path
  r = .directory~new
  r['package_object_id'] = 'oorexx://package/' || path
  r['member_path'] = path
  r['actor'] = actorName()
  return r

actorName: procedure
  actor = value('SSCS_ACTOR', , 'ENVIRONMENT')
  if strip(actor) = '' then actor = 'llm-coding-workbench'
  return actor

receiptRevision: procedure
  use arg d
  if d == .nil then return ''
  if d~hasIndex('revision_id') then return d['revision_id']
  return ''

::requires 'SemanticSourceStore.cls'
::requires 'SemanticSourceMcpDirect.cls'
::requires 'SemanticSourceDevelopmentDesk.cls'
