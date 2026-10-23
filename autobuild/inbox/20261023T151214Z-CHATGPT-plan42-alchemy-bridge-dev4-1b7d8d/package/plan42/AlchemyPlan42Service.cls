/* AlchemyPlan42Service.cls -- additive Plan42 application capability.
   Contract: plan42.integration/0.1.  Never executes generated source.
   Native ooRexx callers receive structured JSON via .ExternalCall.
   ConnectSelector / RPC / QueueFabric may adapt these methods; none required.
   The compiler bridge performs authoritative source/output boundary checks.
*/
::class AlchemyPlan42Service public

::method init
  expose _container _bridge _engine
  use arg container, bridgePath, engine
  _container = container
  if bridgePath = .nil | bridgePath = '' then bridgePath = 'tools/plan42_bridge.py'
  if engine = .nil | engine = '' then engine = 'auto'
  _bridge = bridgePath
  _engine = engine

::method version
  return 'plan42.integration/0.1'

::method reload
  /* No stale target cache. Every discover resolves the live compiler. */
  return .true

::method intentions
  return .Array~of('plan42.discover', 'plan42.inspect', 'plan42.compile', 'plan42.native.plan', 'plan42.native.inventory')

::method discover
  return self~invoke(.Array~of('discover'))

::method inspect
  use arg specPath
  if \self~safeArg(specPath) then return self~refused('unsafe spec path')
  return self~invoke(.Array~of('inspect', '--spec', specPath))

::method compile
  expose _engine
  use arg specPath, target, outputPath
  if \self~safeArg(specPath) | \self~safeArg(target) then
    return self~refused('unsafe source or target argument')
  if outputPath = .nil | outputPath = '' then do
    a = .Array~of('compile', '--spec', specPath, '--target', target, '--engine', _engine)
  end
  else do
    if \self~safeArg(outputPath) then return self~refused('unsafe output path')
    a = .Array~of('compile', '--spec', specPath, '--target', target, '--engine', _engine, '--output', outputPath)
  end
  return self~invoke(a)

/* Read-only RX2CPP qualification plan. No native build or runtime publication. */
::method nativePlan
  use arg sourcePath, mode, compilerRoot = '', receiptPath = '', modelPath = ''
  if \self~safeArg(sourcePath) | \self~safeArg(mode) then
    return self~refused('unsafe source or compilation mode')
  if compilerRoot \== '' then do
    if \self~safeArg(compilerRoot) then
      return self~refused('unsafe compiler checkout path')
  end
  if receiptPath \== '' then do
    if \self~safeArg(receiptPath) then
      return self~refused('unsafe Plan42 receipt path')
  end
  if modelPath \== '' then do
    if \self~safeArg(modelPath) then return self~refused('unsafe inspector model path')
  end
  args = .Array~of('native-plan', '--source', sourcePath, '--mode', mode)
  if compilerRoot \== '' then do
    args~append('--compiler-root')
    args~append(compilerRoot)
  end
  if receiptPath \== '' then do
    args~append('--receipt')
    args~append(receiptPath)
  end
  if modelPath \== '' then do
    args~append('--model')
    args~append(modelPath)
  end
  return self~invoke(args)

/* Import RX2CPP interpreter-derived code-unit export (never execute it here).
   The export is treated as unauthenticated evidence until pinned runtime qualification. */
::method nativeInventory
  use arg sourcePath, modelPath, mode
  if \self~safeArg(sourcePath) | \self~safeArg(modelPath) | \self~safeArg(mode) then
    return self~refused('unsafe source/model/mode argument')
  return self~invoke(.Array~of('native-inventory', '--source', sourcePath, '--model', modelPath, '--mode', mode))

::method safeArg private
  use arg text
  if text = .nil then return .false
  if text = '' then return .false
  /* Existing ExternalTransport joins arguments into a shell command.
     Allow a deliberately restricted ASCII path/token alphabet only. */
  return verify(text, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-') = 0

::method refused private
  use arg reason
  reply = .Directory~new
  reply~put(.false, 'ok')
  reply~put('input-refused', 'status')
  reply~put(reason, 'message')
  return reply

::method invoke private
  expose _container _bridge
  use arg arguments
  if \self~safeArg(_bridge) then return self~refused('unsafe bridge path')
  xcall = .ExternalCall~new(_container)
  xcall~command = 'python3'
  a = .Array~of(_bridge)
  do item over arguments
    a~append(item)
  end
  xcall~args = a
  xcall~timeout = 60
  xcall~transport = _container~get('transport.isolated')
  rc = xcall~run
  out = xcall~result~stdout
  signal on syntax name BadJson
  reply = .json~new~fromJson(out)
  signal off syntax
  return reply
BadJson:
  signal off syntax
  reply = self~refused('compiler adapter did not return valid JSON')
  reply~put(rc, 'exitCode')
  reply~put(xcall~result~stderr, 'stderr')
  return reply

::requires 'json.cls'
