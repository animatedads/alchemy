/* ooRexx object administration facade for xtp/0.1 dev18.
 * The CLI is only the current bridge into libxtp.  Objects and semantics live
 * here so callers do not depend on command output or carrier-specific address
 * conventions.  A native ooRexx binding can replace _run() without changing
 * these public objects.
 */
::class XTPManager public
::method init
  use arg admin = 'xtp-admin'
  self~admin = admin
::attribute admin

::method peer
  use arg name
  return .XTPPeer~new(self, name)

::method _quote private
  use arg value
  /* shell-safe single-quote: ' becomes '\'' */
  q = value~string
  q = q~changestr("'", "'\\''")
  return "'"q"'"

::method _run private
  use arg command
  out. = ''
  address command command with output stem out. error stem err.
  result = .directory~new
  result['RC'] = rc
  lines = .array~new
  do i = 1 to out.0
    lines~append(out.i)
  end
  result['LINES'] = lines
  errors = .array~new
  do i = 1 to err.0
    errors~append(err.i)
  end
  result['ERRORS'] = errors
  return result

::class XTPPeer public
::method init
  expose manager name
  use arg manager, name
::attribute manager get
::attribute name get

::method addRoute
  use arg route
  cmd = self~manager~admin 'route add' self~manager~_quote(self~name),
        '--layer' route~layer '--carrier' self~manager~_quote(route~carrier),
        '--to' self~manager~_quote(route~destination),
        '--metric' route~metric
  if route~interface <> '' then cmd = cmd '--interface' self~manager~_quote(route~interface)
  if route~wireFilters <> '' then cmd = cmd '--filters' self~manager~_quote(route~wireFilters)
  if route~multicast then cmd = cmd '--multicast'
  r = self~manager~_run(cmd)
  if r['RC'] <> 0 then raise syntax 93.900 array ('XTP route add failed', r['ERRORS'])
  return route

::method removeRoutes
  use arg layer = '', carrier = ''
  cmd = self~manager~admin 'route remove' self~manager~_quote(self~name)
  if layer <> '' then cmd = cmd '--layer' layer
  if carrier <> '' then cmd = cmd '--carrier' self~manager~_quote(carrier)
  return self~manager~_run(cmd)['RC']

::method enableRoutes
  use arg layer = '', carrier = ''
  return self~setRouteState('enable', layer, carrier)

::method disableRoutes
  use arg layer = '', carrier = ''
  return self~setRouteState('disable', layer, carrier)

::method setRouteState private
  use arg state, layer, carrier
  cmd = self~manager~admin 'route' state self~manager~_quote(self~name)
  if layer <> '' then cmd = cmd '--layer' layer
  if carrier <> '' then cmd = cmd '--carrier' self~manager~_quote(carrier)
  return self~manager~_run(cmd)['RC']

::method routes
  r = self~manager~_run(self~manager~admin 'route list' self~manager~_quote(self~name))
  if r['RC'] <> 0 then raise syntax 93.900 array ('XTP route list failed', r['ERRORS'])
  a = .array~new
  do line over r['LINES']
    route = self~routeFromTsv(line)
    if route <> .nil then a~append(route)
  end
  return a

::method bestConnect
  r = self~manager~_run(self~manager~admin 'best-paths' self~manager~_quote(self~name) '--max 1')
  if r['RC'] <> 0 | r['LINES']~items = 0 then return .nil
  return self~routeFromPath(r['LINES'][1])

::method bestPaths
  use arg maximum = 0
  cmd = self~manager~admin 'best-paths' self~manager~_quote(self~name)
  if maximum > 0 then cmd = cmd '--max' maximum
  r = self~manager~_run(cmd)
  if r['RC'] <> 0 then return .array~new
  a = .array~new
  do line over r['LINES']
    route = self~routeFromPath(line)
    if route <> .nil then a~append(route)
  end
  return a


::method pathHealth
  r = self~manager~_run(self~manager~admin 'path list' self~manager~_quote(self~name))
  if r['RC'] <> 0 then raise syntax 93.900 array ('XTP path list failed', r['ERRORS'])
  a = .array~new
  tab = '09'x
  do line over r['LINES']
    parse var line peer (tab) layer (tab) carrier (tab) destination (tab) interface (tab) state (tab) generation (tab) failures (tab) lastError
    if peer <> '' then a~append(.XTPPathHealth~new(layer,carrier,destination,interface,state,generation,failures,lastError))
  end
  return a

::method pathDown
  use arg route, error='administratively marked down'
  cmd = self~manager~admin 'path down' self~manager~_quote(self~name),
        '--layer' route~layer '--carrier' self~manager~_quote(route~carrier),
        '--to' self~manager~_quote(route~destination),
        '--error' self~manager~_quote(error)
  return self~manager~_run(cmd)['RC']

::method beginPathRequalification
  use arg route
  cmd = self~manager~admin 'path probe' self~manager~_quote(self~name),
        '--layer' route~layer '--carrier' self~manager~_quote(route~carrier),
        '--to' self~manager~_quote(route~destination)
  return self~manager~_run(cmd)['RC']

::method pathRequalified
  use arg route, timeoutMs=250, retries=12
  cmd = self~manager~admin 'path qualify' self~manager~_quote(self~name),
        '--layer' route~layer '--carrier' self~manager~_quote(route~carrier),
        '--to' self~manager~_quote(route~destination),
        '--timeout-ms' timeoutMs '--retries' retries
  return self~manager~_run(cmd)['RC']

::method forcePathUp
  use arg route
  cmd = self~manager~admin 'path force-up' self~manager~_quote(self~name),
        '--layer' route~layer '--carrier' self~manager~_quote(route~carrier),
        '--to' self~manager~_quote(route~destination)
  return self~manager~_run(cmd)['RC']

::method routeFromTsv private
  use arg line
  tab = '09'x
  parse var line peer (tab) layer (tab) carrier (tab) destination (tab) interface (tab) metric (tab) state (tab) filters (tab) mode
  if peer = '' then return .nil
  route = .XTPRoute~new(layer, carrier, destination, interface, metric, filters, mode='multicast')
  route~enabled = (state = 'enabled')
  return route

::method routeFromPath private
  use arg line
  /* best-paths output is stable key=value text for the bridge. */
  if line~word(1) <> 'PATH' then return .nil
  d = .directory~new
  do i = 2 to line~words
    token = line~word(i)
    p = token~pos('=')
    if p > 1 then d[token~left(p-1)] = token~substr(p+1)
  end
  route = .XTPRoute~new(d['layer'], d['carrier'], d['to'], d['interface'], d['metric'], d['filters'], d['multicast']='1')
  route~enabled = .true
  return route

::class XTPRoute public
::method init
  expose layer carrier destination interface metric wireFilters enabled multicast
  use arg layer, carrier, destination, interface = '', metric = 100, wireFilters = '', multicast = .false
  enabled = .true
::attribute layer
::attribute carrier
::attribute destination
::attribute interface
::attribute metric
::attribute wireFilters
::attribute enabled
::attribute multicast
::method l2 class
  use arg destination, interface, metric = 100, wireFilters = ''
  return self~new(2, 'l2', destination, interface, metric, wireFilters)
::method l3 class
  use arg destination, metric = 100, wireFilters = ''
  return self~new(3, 'raw36', destination, '', metric, wireFilters)
::method l4 class
  use arg carrier, destination, metric = 100, wireFilters = ''
  return self~new(4, carrier, destination, '', metric, wireFilters)
::method multicastL2 class
  use arg destination, interface, metric=100, wireFilters=''
  return self~new(2,'l2',destination,interface,metric,wireFilters,.true)
::method multicastL3 class
  use arg destination, metric=100, wireFilters=''
  return self~new(3,'raw36',destination,'',metric,wireFilters,.true)
::method multicastL4 class
  use arg destination, metric=100, wireFilters=''
  return self~new(4,'udp',destination,'',metric,wireFilters,.true)

::class XTPWireFilterChain public
::method init
  expose filters
  filters = .array~new
::attribute filters get
::method add
  expose filters
  use arg name
  select
    when name = 'zero-block' | name = 'zero' then filters~append('zero-block')
    when name = 'crunch' then filters~append('crunch')
    otherwise raise syntax 93.900 array ('Unknown XTP wire filter', name)
  end
  return self
::method spec
  expose filters
  s = ''
  do f over filters
    if s <> '' then s = s','
    s = s || f
  end
  return s


::class XTPPathHealth public
::method init
  expose layer carrier destination interface state generation failures lastError
  use arg layer,carrier,destination,interface,state,generation,failures,lastError=''
::attribute layer get
::attribute carrier get
::attribute destination get
::attribute interface get
::attribute state get
::attribute generation get
::attribute failures get
::attribute lastError get
::method eligible
  expose state
  return state='UP'
