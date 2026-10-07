/*----------------------------------------------------------------------------*/
/* GDB/MI protocol adapter primitives. MI syntax remains below DebugProvider.  */
/*----------------------------------------------------------------------------*/

::class GdbMiBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "debug.provider.gdbmi/0.1"

::class GdbMiRecord public
::attribute token get
::attribute prefix get
::attribute recordClass get
::attribute results get
::attribute text get
::attribute raw get
::method init
  expose token prefix recordClass results text raw
  use strict arg tokenArg='',prefixArg='',classArg='',resultsArg=.nil,textArg='',rawArg=''
  token=tokenArg~string; prefix=prefixArg~string; recordClass=classArg~string
  if resultsArg==.nil then results=.directory~new; else results=resultsArg
  text=textArg; raw=rawArg

::class GdbMiParser public
::method parse class
  use strict arg line
  raw=line~strip('T','0D0A'x)
  if raw=='' then return .nil
  posi=1; token=''
  do while posi<=raw~length & _miDigit(substr(raw,posi,1))
    token=token||substr(raw,posi,1); posi+=1
  end
  if posi>raw~length then return .GdbMiRecord~new(token,'','','','',raw)
  prefix=substr(raw,posi,1); posi+=1
  if pos(prefix,'^*+=~@&')==0 then return .GdbMiRecord~new(token,prefix,'',.nil,substr(raw,posi),raw)
  if pos(prefix,'~@&')>0 then do
    text=substr(raw,posi)
    if text~left(1)=='"' then do
      st=.MiState~new(text); text=st~parseCString
    end
    return .GdbMiRecord~new(token,prefix,'',.nil,text,raw)
  end
  rest=substr(raw,posi); comma=pos(',',rest)
  if comma==0 then return .GdbMiRecord~new(token,prefix,rest,.directory~new,'',raw)
  cls=substr(rest,1,comma-1); st=.MiState~new(substr(rest,comma+1)); results=st~parseResults
  return .GdbMiRecord~new(token,prefix,cls,results,'',raw)

::class MiState private
::method init
  expose s p
  use strict arg input
  s=input; p=1
::method peek private
  expose s p
  if p>s~length then return ''
  return substr(s,p,1)
::method take private
  expose s p
  if p>s~length then return ''
  c=substr(s,p,1); p+=1; return c
::method parseResults
  expose s p
  d=.directory~new
  do while p<=s~length
    name=self~parseName
    if name=='' then leave
    if self~take<>'=' then leave
    d[name]=self~parseValue
    if self~peek==',' then self~take
    else leave
  end
  return d
::method parseName private
  expose s p
  out=''
  do while p<=s~length
    c=self~peek
    if c=='=' | c==',' | c==']' | c=='}' then leave
    out=out||self~take
  end
  return out
::method parseValue private
  c=self~peek
  select
    when c=='"' then return self~parseCString
    when c=='{' then return self~parseTuple
    when c=='[' then return self~parseList
    otherwise do
      out=''
      do while self~peek<>'' & self~peek<>',' & self~peek<>']' & self~peek<>'}'
        out=out||self~take
      end
      return out
    end
  end
::method parseCString
  if self~take<>'"' then return ''
  out=''
  do while self~peek<>''
    c=self~take
    if c=='"' then leave
    if c=='\\' then do
      e=self~take
      select
        when e=='n' then out=out||'0A'x
        when e=='r' then out=out||'0D'x
        when e=='t' then out=out||'09'x
        when e=='"' then out=out||'"'
        when e=='\\' then out=out||'\\'
        otherwise out=out||e
      end
    end
    else out=out||c
  end
  return out
::method parseTuple private
  self~take
  d=self~parseResults
  if self~peek=='}' then self~take
  return d
::method parseList private
  self~take
  a=.array~new
  do while self~peek<>'' & self~peek<>']'
    /* MI lists can contain either values or result pairs.  Preserve a result
       pair as a one-entry Directory so duplicate names are not discarded. */
    saveP=self~position
    name=self~parseName
    if self~peek=='=' then do
      self~take; d=.directory~new; d[name]=self~parseValue; a~append(d)
    end
    else do
      self~position=saveP; a~append(self~parseValue)
    end
    if self~peek==',' then self~take
  end
  if self~peek==']' then self~take
  return a
::attribute position get private
::attribute position set private

::class GdbMiProjector public
::method providerEvent class
  use strict arg record
  if record==.nil then return .nil
  if record~prefix=='=' then do
    select
      when record~recordClass=='thread-created' then return .DebugProviderEvent~new(.DebugProviderEvents~THREAD_STARTED,record~results['id'])
      when record~recordClass=='thread-exited' then return .DebugProviderEvent~new(.DebugProviderEvents~THREAD_EXITED,record~results['id'])
      otherwise return .nil
    end
  end
  if record~prefix<>'*' then return .nil
  if record~recordClass=='running' then return .DebugProviderEvent~new(.DebugProviderEvents~RUNNING,record~results)
  if record~recordClass<>'stopped' then return .nil
  r=record~results; reason=''; if r~hasIndex('reason') then reason=r['reason']
  data=.directory~new
  if r~hasIndex('thread-id') then data['threadId']=r['thread-id']
  if r~hasIndex('frame') then data['frame']=self~frameFromMi(r['frame'])
  select
    when reason=='breakpoint-hit' then do
      if r~hasIndex('bkptno') then data['providerId']=r['bkptno']; else data['providerId']=''
      return .DebugProviderEvent~new(.DebugProviderEvents~BREAKPOINT_HIT,data)
    end
    when reason=='end-stepping-range' | reason=='function-finished' | reason=='location-reached' then return .DebugProviderEvent~new(.DebugProviderEvents~STEP_COMPLETED,data)
    when reason=='signal-received' then do
      if r~hasIndex('signal-name') then data['signalName']=r['signal-name']
      if r~hasIndex('signal-meaning') then data['signalMeaning']=r['signal-meaning']
      return .DebugProviderEvent~new(.DebugProviderEvents~SIGNAL_RECEIVED,data)
    end
    when reason~left(6)=='exited' then do
      code=0; if r~hasIndex('exit-code') then code=r['exit-code']
      return .DebugProviderEvent~new(.DebugProviderEvents~EXITED,code)
    end
    otherwise return .DebugProviderEvent~new(.DebugProviderEvents~STOPPED,data)
  end

::method frameFromMi class
  use strict arg d
  func=''; file=''; line=0; addr=''
  if d~hasIndex('func') then func=d['func']
  if d~hasIndex('fullname') then file=d['fullname']; else if d~hasIndex('file') then file=d['file']
  if d~hasIndex('line') then line=d['line']+0
  if d~hasIndex('addr') then addr=d['addr']
  return .DebugFrame~new('gdb:'||addr,0,.DebugLocation~new(func,file,line,0,addr),'native')

::routine _miDigit
  use strict arg c
  return pos(c,'0123456789')>0

::requires "DebugRuntime.cls"
