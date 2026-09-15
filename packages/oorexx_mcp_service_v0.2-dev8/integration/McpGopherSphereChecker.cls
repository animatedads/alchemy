/* Gopher-backed sphere resolution for ooRexx MCP Project Service v0.1. */

::class McpGopherSphereChecker public
::method init
  expose gopherExecutable apiRollup overrideDir
  use strict arg gopherExecutable, apiRollup='', overrideDir=''
  if gopherExecutable='' then raise syntax 40.900 array('Gopher executable is required')

::method check
  expose gopherExecutable apiRollup overrideDir
  use strict arg args
  sphereId=.McpProjectUtil~required(args,'sphereId')
  if sphereId='' then return .WireUIResult~failure('INVALID_ARGUMENT','sphereId is required')
  if \self~safeSphereId(sphereId) then return .WireUIResult~failure('INVALID_ARGUMENT','sphereId contains unsupported characters')

  outFile=SysTempFileName('/tmp/oorexx_mcp_gopher_??????')
  command=self~quote(gopherExecutable)||' sphere resolve '||self~quote(sphereId)
  if apiRollup<>'' then command=command||' --api-rollup '||self~quote(apiRollup)
  if overrideDir<>'' then command=command||' --override-dir '||self~quote(overrideDir)
  command=command||' > '||self~quote(outFile)||' 2>&1'
  address system command
  commandRc=rc

  if stream(outFile,'c','query exists')='' then -
    return .WireUIResult~failure('SPHERE_CHECK_FAILED','Gopher produced no result')
  text=charin(outFile,1,chars(outFile))
  call stream outFile,'c','close'
  call SysFileDelete outFile
  signal on syntax name parseFailure
  parsed=.json~fromJSON(text)
  signal off syntax

  value=.directory~new
  value['schema']='oorexx.mcp.sphere.check/1'
  value['sphereId']=sphereId
  value['gopherCommandRc']=commandRc
  value['gopher']=parsed
  if parsed~hasIndex('operation_status') then do
    operationStatus=parsed['operation_status']
    operationClass=.McpProjectUtil~optional(operationStatus,'class','')
    operationRc=.McpProjectUtil~optional(operationStatus,'rc','1')
    if operationClass='FOUND' & operationRc='0' then -
      return .WireUIResult~success(value,'SPHERE_RESOLVED')
    return .WireUIResult~failure('SPHERE_NOT_FOUND','Gopher did not resolve the requested sphere',value)
  end
  return .WireUIResult~failure('SPHERE_CHECK_FAILED','Gopher result did not contain operation_status',value)

parseFailure:
  detail='Gopher output was not valid JSON'
  if text<>'' then detail=detail||': '||text~left(240)
  return .WireUIResult~failure('SPHERE_CHECK_FAILED',detail)

::method safeSphereId private
  use strict arg value
  if value='' then return .false
  do i=1 to value~length
    c=value~substr(i,1)
    if \(c~datatype('A') | c~datatype('N') | c='-' | c='_' | c='.') then return .false
  end
  return .true

::method quote private
  use strict arg value
  /* Configuration paths are trusted local inputs; reject shell metacharacter
   * that would break the deliberately simple POSIX single-quote envelope. */
  if value~pos("'")>0 then raise syntax 40.900 array('Unsupported apostrophe in configured path/value',value)
  return "'"||value||"'"

::requires 'McpProjectService.cls'
::requires 'json.cls'
