/* ShellNet.cls - the node's network as read-only shell objects
   Architecture: Tom Dyer (24 November 2026): objects to examine networks, so
   an agent working on an MU finds the issues quickly.
   Coding: Claude (Opus 5.5).

   net = .Network~new
   net~interfaces~~table          /sys/class/net
   net~addresses~~table           ip -j addr (iproute2), else /proc/net/if_inet6 and fib_trie
   net~routes~~table              /proc/net/route and /proc/net/ipv6_route
   net~listening~~table           /proc/net/tcp, tcp6, udp, udp6
   net~firewall~rules~~table      nft -a list ruleset (needs root)

   Nothing here changes anything: no protected methods. Programs (ip, nft)
   run through oorexx_process, argv only, with a timeout. */
::requires 'ShellObject.cls'
::requires 'ShellLog.cls'
::requires 'Process.cls'

::class Network public inherit ShellObject
::constant SHELL_HELP "net~interfaces, net~addresses, net~routes and net~listening are ShellCollections (sortedBy, first, DO OVER). net~interface(name) gives one. net~firewall gives the nft ruleset (rules, sets, chains); reading it needs root. Read-only."

::method interfaces
  rows = .Array~new
  list = .File~new('/sys/class/net')~list
  if list == .nil then return .ShellCollection~new(rows)
  do name over list~sortWith(.CaselessComparator~new)
    rows~append(.NetInterface~new(name))
  end
  return .ShellCollection~new(rows)

::method interface
  use strict arg name
  if \.File~new('/sys/class/net/'name)~exists then raise syntax 93.900 array ('No interface' name)
  return .NetInterface~new(name)

::method addresses
  ip = whichProgram('ip')
  if ip \== '' then do
    x = runArgv(.Array~of(ip, '-j', 'addr', 'show'))
    if x \== .nil, x~exitCode = 0 then return .ShellCollection~new(addressesFromJson(x~stdout))
  end
  return .ShellCollection~new(addressesFromProc())

::method routes
  rows = .Array~new
  lines = readLines('/proc/net/route')
  do i = 2 to lines~items
    parse value lines[i] with dev dest gw flags . . metric mask .
    if dev == '' then iterate
    rows~append(.NetRoute~new('ipv4', hexToIpv4(dest)'/'maskBits(mask), hexToIpv4(gw), dev, metric))
  end
  do l over readLines('/proc/net/ipv6_route')
    parse var l dest plen . . nexthop metric . . . dev .
    if dev == '' | dev == 'lo' then iterate
    rows~append(.NetRoute~new('ipv6', hexToIpv6(dest)'/'x2d(plen), hexToIpv6(nexthop), dev, x2d(metric)))
  end
  return .ShellCollection~new(rows)

::method listening
  rows = .Array~new
  do proto over .Array~of('tcp', 'tcp6', 'udp', 'udp6')
    lines = readLines('/proc/net/'proto)
    do i = 2 to lines~items
      parse value lines[i] with . local . state . . . uid . inode .
      want = '0A'; if proto~left(3) == 'udp' then want = '07'
      if state \== want then iterate
      parse var local addr ':' port
      if proto~right(1) == '6' then shown = hexToIpv6Proc(addr)
      else shown = hexToIpv4(addr)
      rows~append(.NetListen~new(proto~strip('T', '6'), proto, shown, x2d(port), uid, inode))
    end
  end
  return .ShellCollection~new(rows)

::method firewall
  return .Firewall~new
::method fields
  return .Array~of('interfaceCount', 'listeningCount')
::method interfaceCount
  return self~interfaces~items~items
::method listeningCount
  return self~listening~items~items
::method identity
  return 'net:'readOne('/proc/sys/kernel/hostname')
::method relatedSamples
  return .Array~of(.Array~of('each net~interfaces item', .NetInterface~new('lo')), -
                   .Array~of('each net~listening item', .NetListen~new('tcp', 'tcp', '0.0.0.0', 22, 0, 0)), -
                   .Array~of('each net~routes item', .NetRoute~new('ipv4', '0.0.0.0/0', '0.0.0.0', 'lo', 0)), -
                   .Array~of('each net~addresses item', .NetAddress~new('lo', 'inet', '127.0.0.1', 8, 'host')), -
                   .Array~of('net~firewall', .Firewall~sample))

::class NetInterface public inherit ShellObject
::constant SHELL_HELP "operstate is up, down or unknown. rxBytes and txBytes count since boot. carrier is 1 when a link is detected."
::method init
  expose name
  use strict arg name
::method name
  expose name
  return name
::method attr private
  expose name
  use strict arg file
  v = readOne('/sys/class/net/'name'/'file)
  if v == .nil then return ''
  return v
::method operstate
  return self~attr('operstate')
::method mtu
  return self~attr('mtu')
::method mac
  return self~attr('address')
::method carrier
  return self~attr('carrier')
::method rxBytes
  return self~attr('statistics/rx_bytes')
::method txBytes
  return self~attr('statistics/tx_bytes')
::method identity
  expose name
  return 'if:'name':'self~attr('ifindex')
::method fields
  return .Array~of('name', 'operstate', 'mtu', 'mac', 'carrier', 'rxBytes', 'txBytes')

::class NetAddress public inherit ShellObject
::method init
  expose dev family address prefix scope
  use strict arg dev, family, address, prefix, scope
::method dev
  expose dev
  return dev
::method family
  expose family
  return family
::method address
  expose address
  return address
::method prefix
  expose prefix
  return prefix
::method scope
  expose scope
  return scope
::method fields
  return .Array~of('dev', 'family', 'address', 'prefix', 'scope')

::class NetRoute public inherit ShellObject
::method init
  expose family destination gateway dev metric
  use strict arg family, destination, gateway, dev, metric
::method family
  expose family
  return family
::method destination
  expose destination
  return destination
::method gateway
  expose gateway
  return gateway
::method dev
  expose dev
  return dev
::method metric
  expose metric
  return metric
::method fields
  return .Array~of('family', 'destination', 'gateway', 'dev', 'metric')

::class NetListen public inherit ShellObject
::constant SHELL_HELP "proto is tcp or udp; family file is tcp, tcp6, udp or udp6. address 0.0.0.0 or :: means every address. uid owns the socket; inode identifies it."
::method init
  expose proto source address port uid inode
  use strict arg proto, source, address, port, uid, inode
::method proto
  expose proto
  return proto
::method source
  expose source
  return source
::method address
  expose address
  return address
::method port
  expose port
  return port
::method uid
  expose uid
  return uid
::method inode
  expose inode
  return inode
::method identity
  expose proto port inode
  return 'listen:'proto':'port':'inode
::method fields
  return .Array~of('proto', 'source', 'address', 'port', 'uid', 'inode')

/* --------------------------------------------------------------- firewall -- */
/* The nft ruleset, read with "nft -a list ruleset" (root). NEWSHELL_NFT may
   name another program that prints a ruleset (tests). */
::class Firewall public inherit ShellObject
::constant SHELL_HELP "fw~rules (family, table, chain, handle, rule), fw~sets (name, type, elements), fw~chains (with hook and policy). fw~ok is 0 when the ruleset could not be read (fw~error says why: usually not root). Read-only: changing the firewall is never done from here."
::method sample class
  return self~new('')
::method init
  expose text error rules sets chains
  use strict arg preset = .nil
  rules = .Array~new; sets = .Array~new; chains = .Array~new; error = ''
  if preset \== .nil then do; text = preset; self~parse; return; end
  prog = value('NEWSHELL_NFT',, 'ENVIRONMENT')
  if prog == '' then argv = .Array~of(whichProgram('nft'), '-a', 'list', 'ruleset')
  else argv = .Array~of(prog)
  if argv[1] == '' then do; error = 'nft is not installed'; text = ''; return; end
  x = runArgv(argv)
  if x == .nil then do; error = 'nft could not be started'; text = ''; return; end
  if x~exitCode \= 0 then do
    error = 'nft exit' x~exitCode':' x~stderr~string~strip~left(120)
    text = ''
    return
  end
  text = x~stdout~string
  self~parse

::method parse private
  expose text rules sets chains
  family = ''; table = ''; chain = ''; setName = ''
  do raw over text~makeArray('0a'x)
    l = raw~strip
    if l == '' then iterate
    handle = ''
    if l~pos('# handle ') > 0 then do
      handle = l~substr(l~lastPos('# handle ') + 9)~word(1)
      l = l~left(l~lastPos('# handle ') - 1)~strip
    end
    select
      when l~word(1) == 'table' then do
        family = l~word(2); table = l~word(3); chain = ''; setName = ''
      end
      when l~word(1) == 'chain' then do
        chain = l~word(2)
        chains~append(.FirewallChain~new(family, table, chain, handle))
      end
      when l~word(1) == 'set' | l~word(1) == 'map' then do
        setName = l~word(2)
        sets~append(.FirewallSet~new(family, table, setName, handle))
      end
      when setName \== '' & l~word(1) == 'type' then sets~lastItem~setType(l~subword(2))
      when setName \== '' & l~word(1) == 'elements' then sets~lastItem~setElements(l~substr(l~pos('{') + 1)~strip('T', '}')~strip)
      when l == '}' then do
        if setName \== '' then setName = ''
        else if chain \== '' then chain = ''
        else table = ''
      end
      when chain \== '' & l~word(1) == 'type' & l~pos('hook') > 0 then chains~lastItem~setHeader(l)
      when chain \== '' & handle \== '' then rules~append(.FirewallRule~new(family, table, chain, handle, l))
      otherwise nop
    end
  end

::method ok
  expose error
  return error == ''
::method error
  expose error
  return error
::method rules
  expose rules
  return .ShellCollection~new(rules~copy)
::method sets
  expose sets
  return .ShellCollection~new(sets~copy)
::method chains
  expose chains
  return .ShellCollection~new(chains~copy)
::method text
  expose text
  return text
::method ruleCount
  expose rules
  return rules~items
::method fields
  return .Array~of('ok', 'ruleCount', 'error')
::method relatedSamples
  return .Array~of(.Array~of('each fw~rules item', .FirewallRule~new('inet', 't', 'input', 1, 'accept')), -
                   .Array~of('each fw~sets item', .FirewallSet~new('inet', 't', 's', 1)), -
                   .Array~of('each fw~chains item', .FirewallChain~new('inet', 't', 'input', 1)))

::class FirewallRule public inherit ShellObject
::method init
  expose family table chain handle rule
  use strict arg family, table, chain, handle, rule
::method family
  expose family
  return family
::method table
  expose table
  return table
::method chain
  expose chain
  return chain
::method handle
  expose handle
  return handle
::method rule
  expose rule
  return rule
/* A kept rule is current only while the same handle still holds the same rule. */
::method identity
  expose family table chain handle
  return 'nft:'family':'table':'chain':'handle
::method isCurrent
  expose family table chain handle rule
  do r over .Firewall~new~rules~items
    if r~identity == self~identity then return r~rule == rule
  end
  return .false
::method fields
  return .Array~of('family', 'table', 'chain', 'handle', 'rule')

::class FirewallSet public inherit ShellObject
::method init
  expose family table name handle type elements
  use strict arg family, table, name, handle
  type = ''; elements = ''
::method setType
  expose type
  use strict arg type
::method setElements
  expose elements
  use strict arg elements
::method name
  expose name
  return name
::method table
  expose table
  return table
::method type
  expose type
  return type
::method elements
  expose elements
  return elements
::method fields
  return .Array~of('table', 'name', 'type', 'elements')

::class FirewallChain public inherit ShellObject
::method init
  expose family table name handle header
  use strict arg family, table, name, handle
  header = ''
::method setHeader
  expose header
  use strict arg header
::method table
  expose table
  return table
::method name
  expose name
  return name
::method hook
  expose header
  if header~pos('hook ') = 0 then return ''
  return header~substr(header~pos('hook ') + 5)~word(1)
::method policy
  expose header
  if header~pos('policy ') = 0 then return ''
  return header~substr(header~pos('policy ') + 7)~word(1)~strip('T', ';')
::method fields
  return .Array~of('table', 'name', 'hook', 'policy')

/* -------------------------------------------------------------- helpers -- */
::routine readLines public
  use strict arg path
  list = .Array~new
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return list
  do forever                                -- /proc files report size 0: read to the end
    l = s~lineIn
    if l == '', s~state \== 'READY' then leave
    list~append(l)
  end
  s~close
  return list

::routine readOne public
  use strict arg path
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return .nil
  v = s~lineIn
  s~close
  return v

::routine whichProgram public
  use strict arg name
  do d over .Array~of('/usr/sbin', '/sbin', '/usr/bin', '/bin', '/usr/local/sbin', '/usr/local/bin')
    if .File~new(d'/'name)~isFile then return d'/'name
  end
  return ''

::routine runArgv public
  use strict arg argv
  spec = .ProcessSpec~new(argv)
  spec~timeoutMs = 15000
  x = .ProcessRunner~new~run(spec)
  if x~failedToStart then return .nil
  return x

::routine hexToIpv4 public
  use strict arg h                           -- little-endian hex, as /proc writes it
  if h~length \= 8 then return h
  return x2d(h~substr(7, 2))'.'x2d(h~substr(5, 2))'.'x2d(h~substr(3, 2))'.'x2d(h~substr(1, 2))

::routine maskBits public
  use strict arg h
  bits = x2b(h)
  return bits~countStr('1')

::routine hexToIpv6 public
  use strict arg h                           -- 32 hex digits in order (ipv6_route, if_inet6)
  if h~length \= 32 then return h
  groups = .Array~new
  do i = 1 to 32 by 4
    g = h~substr(i, 4)~strip('L', '0')
    if g == '' then g = '0'
    groups~append(g~lower)
  end
  return compressIpv6(groups~makeString('L', ':'))

::routine hexToIpv6Proc public
  use strict arg h                           -- /proc/net/tcp6: four little-endian 32-bit words
  if h~length \= 32 then return h
  out = ''
  do w = 0 to 3
    word = h~substr(w * 8 + 1, 8)
    out = out || word~substr(7, 2) || word~substr(5, 2) || word~substr(3, 2) || word~substr(1, 2)
  end
  return hexToIpv6(out)

::routine compressIpv6
  use strict arg text
  parts = text~makeArray(':')
  bestAt = 0; bestLen = 0; at = 0; len = 0
  do i = 1 to parts~items
    if parts[i] == '0' then do
      if len = 0 then at = i
      len += 1
      if len > bestLen then do; bestLen = len; bestAt = at; end
    end
    else len = 0
  end
  if bestLen < 2 then return text
  left = ''; right = ''
  do i = 1 to bestAt - 1; left = left || parts[i]':'; end
  do i = bestAt + bestLen to parts~items; right = right':'parts[i]; end
  out = left~strip('T', ':')'::'right~strip('L', ':')
  return out

::routine addressesFromJson
  use strict arg text
  rows = .Array~new
  signal on syntax name bad
  list = .JSON~fromJSON(text~string)
  signal off syntax
  do link over list
    dev = link['ifname']
    info = link['addr_info']
    if info == .nil then iterate
    do a over info
      rows~append(.NetAddress~new(dev, a['family'], a['local'], a['prefixlen'], a['scope']))
    end
  end
  return rows
bad:
  return addressesFromProc()

/* Without iproute2: IPv6 from if_inet6; IPv4 local addresses from fib_trie (no device). */
::routine addressesFromProc
  rows = .Array~new
  do l over readLines('/proc/net/if_inet6')
    parse var l hex . plen scope . dev .
    rows~append(.NetAddress~new(dev, 'inet6', hexToIpv6(hex), x2d(plen), scope))
  end
  lines = readLines('/proc/net/fib_trie')
  seen = .Set~new
  do i = 2 to lines~items
    if lines[i]~pos('/32 host LOCAL') > 0 then do
      addr = lines[i - 1]~strip~strip('L', '|')~strip('L', '-')~strip
      if addr~verify('0123456789.') = 0, \seen~hasIndex(addr) then do
        seen~put(addr)
        rows~append(.NetAddress~new('', 'inet', addr, 32, 'host'))
      end
    end
  end
  return rows

::requires 'json.cls'
