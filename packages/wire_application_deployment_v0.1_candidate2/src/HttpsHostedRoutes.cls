/* Deployment-owned HTTPS routes; static routes remain separately immutable. */
::class HttpsHostedRoutes public
::method init
  expose snapshot
  snapshot=.directory~new
::method generation unguarded
  expose snapshot
  use strict arg method,path
  key=method~upper||' '||path
  if \snapshot~hasIndex(key) then return ''
  return snapshot[key][2]
::method lookup unguarded
  expose snapshot
  use strict arg method,path
  key=method~upper||' '||path
  if \snapshot~hasIndex(key) then return .nil
  return snapshot[key]
::method methodsForPath unguarded
  expose snapshot
  use strict arg path
  methods=''
  suffix=' '||path
  do k over snapshot
    if k~right(suffix~length)==suffix then do
      if methods<>'' then methods=methods||', '
      methods=methods||k~word(1)
    end
  end
  return methods
::method publish guarded
  expose snapshot
  use strict arg method,path,owner,generation,target,selector,expected=''
  if \self~valid(method,path,owner,generation,selector) then return .false
  if target==.nil then return .false
  key=method~upper||' '||path
  old=snapshot[key]
  if old==.nil then do
    if expected<>'' then return .false
  end
  else do
    if old[1]<>owner | old[2]<>expected then return .false
    if generation==old[2] then return .false
  end
  next=.directory~new
  do k over snapshot
    next[k]=snapshot[k]
  end
  next[key]=.array~of(owner,generation,target,selector)
  snapshot=next
  return .true
::method retire guarded
  expose snapshot
  use strict arg method,path,owner,expected
  key=method~upper||' '||path
  if \snapshot~hasIndex(key) then return .false
  old=snapshot[key]
  if old[1]<>owner | old[2]<>expected then return .false
  next=.directory~new
  do k over snapshot
    if k<>key then next[k]=snapshot[k]
  end
  snapshot=next
  return .true
::method valid private
  use strict arg method,path,owner,generation,selector
  if method=='' | method~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ')<>0 then return .false
  if path=='' | path~left(1)<>'/' then return .false
  if path~pos('?')>0 | path~pos('#')>0 | path~pos('//')>0 then return .false
  if owner=='' | generation=='' | selector=='' then return .false
  return .true
