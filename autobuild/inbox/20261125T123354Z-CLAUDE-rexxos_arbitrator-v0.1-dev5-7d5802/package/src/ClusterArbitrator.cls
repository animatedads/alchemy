/* rexxos_arbitrator v0.1-dev5: cross-arbitration across MUs.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   Tom Dyer, 2026-11-25: "we have a lot of access of the website from the
   USA today" can be answered by a pragmatic up and move of the website's MI,
   wholesale, along with a domain-name repoint.  If the Rasen Falcon website
   is accessed from Australia between 22:00 and 08:00 GMT it should be
   served from that zone; from 08:00 GMT it runs on UK tin.

   A ServicePlacement says where a service should run: a home zone, and
   rules (a zone, an optional GMT window, a minimum share of the access).
   The first rule that matches wins; otherwise home.  A service stays where
   it is for a minimum residence, so it does not ping-pong.

   The ClusterArbitrator turns that into a plan across MUs.  Each MU's own
   MachineArbitrator plans its part; the cluster only orders the parts and
   adds the routing steps.

   Address for service, not for equipment (Tom Dyer, 2026-11-25).  Inside
   the mesh a client addresses the service's XTP address, never a machine,
   so a move is a route change: the target's XTP daemon registers the
   service and the route is published (LDAP); nothing the clients hold
   changes.  Only the public edge may name equipment:
   - edge GATEWAY: the public name points at XTP gateways that forward to
     the service address wherever it lives; DNS never changes on a move.
   - edge DNS: the public name points at the machine, so DNS is repointed
     and old answers are left to expire.
   The order of the parts:
   - state on a FABRIC (shared truth): the new copy is activated and checked,
     the route moves, (edge DNS) DNS is repointed and old answers expire,
     then the old copy is released.  Both serve during the overlap.
   - state in a CHECKPOINT (one owner at a time): the old copy is
     deactivated first, then activated on the target, checked, and the
     route moves.  Clients see an outage of the activation time (plus the
     DNS TTL with edge DNS).
   - TEMPORARY state cannot move.

   dev3: muDown also restores the services that lived on the dead MU, and
   its plan is a RECOVERY plan: pre-approved while every change only
   restores (see Arbitrator.cls).  A DNS edge changes public exposure, so a
   DNS-edge service's recovery needs approval; behind gateways it does not.

   Nothing here touches a real machine or a real DNS record. */

::requires 'Arbitrator.cls'

/* ------------------------------------------------------------------ */
::class ClusterStep public subclass ProvisionStep
::method init
  expose mu role address
  use strict arg kind, demand, cause, mu, role = '', sizeMiB = 0, mode = '', status = 'PLANNED', note = '', address = ''
  if wordpos(role, 'TARGET SOURCE ROUTE EDGE') = 0 then raise syntax 93.900 array ('Unknown cluster step role' role)
  self~init:super(kind, demand, cause, sizeMiB, mode, status, note)
::method kinds class
  return .ProvisionStep~kinds 'CHECK_SERVING FENCE_ROLE ROUTE_SERVICE ANNOUNCE_ROLE REPOINT_DNS WAIT_DNS'
/* The service address a ROUTE_SERVICE or FENCE_ROLE step is about. */
::attribute address get
::method fromMachine class
  use strict arg step, mu, role
  return self~new(step~kind, step~demand, step~cause, mu, role, step~sizeMiB, step~mode, step~status, step~note)
::attribute mu get
::attribute role get
::method changesMachine
  if wordpos(self~kind, 'CHECK_SERVING WAIT_DNS') > 0 then return .false
  return self~changesMachine:super
::method inverse
  if self~kind == 'REPOINT_DNS' then return 'REPOINT_DNS (back to the old address)'
  if self~kind == 'ROUTE_SERVICE' then return 'ROUTE_SERVICE (back to the old MU)'
  if self~kind == 'ANNOUNCE_ROLE' then return 'ANNOUNCE_ROLE (a newer record, never an older one)'
  return self~inverse:super
::method noteIsActions
  return wordpos(self~kind, 'CHECK_SERVING FENCE_ROLE ROUTE_SERVICE ANNOUNCE_ROLE REPOINT_DNS WAIT_DNS') > 0
::method actions
  if self~noteIsActions then return self~note~makeArray(';')
  return self~actions:super
::method string
  expose mu
  return '['mu']' self~string:super
::method toText
  expose mu role address
  base = self~toText:super
  return 'CSTEP|'mu'|'role'|'address'|'substr(base, length('STEP|') + 1)
::method fromText class
  use strict arg line, demands
  parse var line tag '|' mu '|' role '|' address '|' rest
  if tag \== 'CSTEP' then raise syntax 93.900 array ('Not a cluster step record:' line)
  f = .ProvisionStep~fieldsFromText('STEP|'rest, demands)
  return self~new(f[1], f[2], f[3], mu, role, f[4], f[5], f[6], f[7], address)

/* ------------------------------------------------------------------ */
::class ServicePlacement public
::method init
  expose demand xtpService edge dnsName ttlSec homeZone minResidenceSec rules
  use strict arg demand, xtpService, edge, dnsName, ttlSec, homeZone, minResidenceSec = 3600
  if \demand~isA(.Demand) then raise syntax 93.900 array ('ServicePlacement needs a Demand')
  edge = edge~upper
  if wordpos(edge, 'GATEWAY DNS NONE') = 0 then raise syntax 93.900 array ('Service' demand~id': edge must be GATEWAY, DNS or NONE')
  if (edge == 'NONE') \== (dnsName == '') then raise syntax 93.900 array ('Service' demand~id': a public name needs an edge, and an edge a public name')
  do v over .Array~of(ttlSec, minResidenceSec)
    if \v~datatype('W') then raise syntax 93.900 array ('Service' demand~id': times must be whole seconds')
    if v < 0 then raise syntax 93.900 array ('Service' demand~id': times must not be negative')
  end
  rules = .Array~new
::attribute demand get
::attribute xtpService get
::attribute edge get
::attribute dnsName get
::attribute ttlSec get
::attribute homeZone get
::attribute minResidenceSec get
::method id
  expose demand
  return demand~id
::method rulesList
  expose rules
  return rules
/* zone, GMT window 'HH:MM' to 'HH:MM' ('' for any time), minimum share of access in percent. */
::method rule
  expose rules demand
  use strict arg zone, fromHHMM, toHHMM, minSharePct
  if (fromHHMM == '') \== (toHHMM == '') then raise syntax 93.900 array ('Service' demand~id': a window needs both ends')
  if fromHHMM \== '' then do
    call secondsOf fromHHMM; call secondsOf toHHMM
  end
  if \minSharePct~datatype('W') then raise syntax 93.900 array ('Service' demand~id': share must be a whole percent')
  if minSharePct < 0 | minSharePct > 100 then raise syntax 93.900 array ('Service' demand~id': share must be 0-100')
  r = .Directory~new; r['ZONE'] = zone; r['FROM'] = fromHHMM; r['TO'] = toHHMM; r['SHARE'] = minSharePct
  rules~append(r)
  return self
/* Returns .Array~of(zone, reason).  now is GMT seconds; shares: zone -> percent. */
::method zoneFor
  expose rules homeZone
  use strict arg now, shares
  sod = now // 86400
  do r over rules
    share = 0
    if shares~hasIndex(r['ZONE']) then share = shares[r['ZONE']]
    if share < r['SHARE'] then iterate
    if r['FROM'] \== '' then do
      f = secondsOf(r['FROM']); t = secondsOf(r['TO'])
      if f < t then inside = (sod >= f & sod < t)
      else inside = (sod >= f | sod < t)
      if \inside then iterate
      return .Array~of(r['ZONE'], r['ZONE'] share'% of access, inside' r['FROM']'-'r['TO'] 'GMT')
    end
    return .Array~of(r['ZONE'], r['ZONE'] share'% of access')
  end
  return .Array~of(homeZone, 'home zone')

::routine secondsOf
  use strict arg hhmm
  parse var hhmm hh ':' mm
  if \hh~datatype('W') | \mm~datatype('W') | hh < 0 | hh > 23 | mm < 0 | mm > 59 | hhmm~length \= 5 then
    raise syntax 93.900 array ('Time must be HH:MM, not' hhmm)
  return hh * 3600 + mm * 60

/* ------------------------------------------------------------------ */
/* A service kept as a main and a hot spare (Tom Dyer, 2026-11-25): wherever
   they are this minute, clients address NAME.main and NAME.spare.  Those
   are service addresses, kept on separate sites, never addresses of nodes
   that may vanish when someone pulls a power plug.  When the main goes
   down the spare becomes the main, and a new spare is made on another site.
   Instances are NAME-1, NAME-2, ...; roles point at instances. */
::class RolePair public
::method init
  expose name template selfRouting
  use strict arg name, template, selfRouting = .false
  if \selfRouting~isA(.String) | wordpos(selfRouting, '0 1') = 0 then raise syntax 93.900 array ('RolePair' name': selfRouting must be .true or .false')
  if \template~isA(.Demand) then raise syntax 93.900 array ('RolePair' name 'needs a Demand as its template')
  if template~stateWhere \== 'FABRIC' then raise syntax 93.900 array ('RolePair' name': a hot spare needs its state replicated on a fabric')
::attribute name get
::attribute template get
/* .true for the pair that carries the routes itself (LDAP): its own role
   moves cannot be published through it, so they are announced directly. */
::attribute selfRouting get
::method mainAddress
  expose name
  return name'.main'
::method spareAddress
  expose name
  return name'.spare'
::method instance
  expose name template
  use strict arg n
  t = template
  return .Demand~new(name'-'n, t~priority, t~ramMiB, t~pageableMiB, t~storageMiB, t~storageWhere, t~wantsRamSpeed, t~durability, t~cacheMode, t~stateWhere)

/* ------------------------------------------------------------------ */
::class ClusterArbitrator public
::method init
  expose mus services decisions pairs
  mus = .Directory~new            /* id -> Directory ZONE ARB ADDRESS HELD DOWN */
  services = .Directory~new       /* id -> Directory SVC MU SINCE */
  pairs = .Directory~new          /* name -> Directory PAIR MAIN MAINMU SPARE SPAREMU NEXT EPOCH */
  decisions = .Array~new
::method addMu
  expose mus
  use strict arg id, zone, arbitrator, address
  if \arbitrator~isA(.MachineArbitrator) then raise syntax 93.900 array ('MU' id 'needs a MachineArbitrator')
  if mus~hasIndex(id) then raise syntax 93.900 array ('MU' id 'added twice')
  m = .Directory~new; m['ZONE'] = zone; m['ARB'] = arbitrator; m['ADDRESS'] = address; m['HELD'] = .Array~new; m['DOWN'] = .false
  mus[id] = m
  return self
/* An MU's own arbitrator. */
::method mu
  expose mus
  use strict arg muId
  if \mus~hasIndex(muId) then raise syntax 93.900 array ('No MU' muId)
  return mus[muId]['ARB']
/* The demands an MU holds; its own arbitrator plans with these. */
::method held
  expose mus
  use strict arg muId
  return mus[muId]['HELD']
::method hold
  expose mus
  use strict arg muId, d
  if \mus~hasIndex(muId) then raise syntax 93.900 array ('No MU' muId)
  if indexById(mus[muId]['HELD'], d~id) = 0 then mus[muId]['HELD']~append(d)
  return self
::method place
  expose mus services
  use strict arg svc, muId, since
  if \mus~hasIndex(muId) then raise syntax 93.900 array ('No MU' muId)
  s = .Directory~new; s['SVC'] = svc; s['MU'] = muId; s['SINCE'] = since
  services[svc~id] = s
  self~hold(muId, svc~demand)
  return self
::method whereIs
  expose services
  use strict arg id
  return services[id]['MU']
::method decisions
  expose decisions
  return decisions

/* access: service id -> Directory zone -> hits over the observation window. */
::method planMoves
  expose mus services decisions
  use strict arg now, access
  plan = .ProvisionPlan~new
  decisions = .Array~new
  do id over services~allIndexes~sort
    s = services[id]; svc = s['SVC']; d = svc~demand
    src = s['MU']; srcZone = mus[src]['ZONE']
    shares = .Directory~new
    if access~hasIndex(id) then do
      hits = access[id]; total = 0
      do z over hits~allIndexes; total += hits[z]; end
      if total > 0 then do z over hits~allIndexes; shares[z] = hits[z] * 100 % total; end
    end
    pick = svc~zoneFor(now, shares); zone = pick[1]
    if zone == srcZone then do
      decisions~append(id': stay in' zone '('pick[2]')')
      iterate
    end
    if now - s['SINCE'] < svc~minResidenceSec then do
      decisions~append(id': wants' zone '('pick[2]') but held in' srcZone 'for its minimum residence until' s['SINCE'] + svc~minResidenceSec's')
      iterate
    end
    if \d~deactivatable then do
      decisions~append(id': wants' zone 'but its state is TEMPORARY; it cannot move')
      iterate
    end
    found = self~targetIn(zone, d, src, now)
    if found == .nil then do
      decisions~append(id': wants' zone '('pick[2]') but no MU there can take it without displacing other work')
      iterate
    end
    dst = found[1]; dstPlan = found[2]
    srcArb = mus[src]['ARB']
    srcSteps = srcArb~releaseSteps(d, 'moving to' dst 'in' zone)
    addr = mus[dst]['ADDRESS']; oldAddr = mus[src]['ADDRESS']
    check = .ClusterStep~new('CHECK_SERVING', d, 'prove the new copy serves before anyone is sent to it', dst, 'TARGET',,,, 'call' svc~xtpService 'on' dst 'directly over XTP;compare the content digest with the fabric copy')
    route = .ClusterStep~new('ROUTE_SERVICE', d, pick[2], dst, 'ROUTE',,,, 'register' svc~xtpService 'with' dst"'s XTP daemon;publish the route (LDAP) and withdraw" src"'s;clients keep the same service address", svc~xtpService)
    edgeSteps = .Array~new
    if svc~edge == 'DNS' then do
      edgeSteps~append(.ClusterStep~new('REPOINT_DNS', d, 'the public name' svc~dnsName 'names equipment', dst, 'EDGE',,,, 'point' svc~dnsName 'at' addr';the old address' oldAddr 'keeps its copy until the old record expires'))
      if d~stateWhere == 'FABRIC' then
        edgeSteps~append(.ClusterStep~new('WAIT_DNS', d, 'let cached DNS answers expire before the old copy goes', src, 'EDGE',,,, 'wait' svc~ttlSec 's (the record''s TTL)'))
    end
    if d~stateWhere == 'FABRIC' then do
      /* Shared truth: both copies serve during the overlap. */
      do st over dstPlan~planned; plan~add(.ClusterStep~fromMachine(st, dst, 'TARGET')); end
      plan~add(check); plan~add(route)
      do st over edgeSteps; plan~add(st); end
      do st over srcSteps; plan~add(.ClusterStep~fromMachine(st, src, 'SOURCE')); end
    end
    else do
      /* One owner at a time: hand the checkpoint over. */
      do st over srcSteps; plan~add(.ClusterStep~fromMachine(st, src, 'SOURCE')); end
      do st over dstPlan~planned; plan~add(.ClusterStep~fromMachine(st, dst, 'TARGET')); end
      plan~add(check); plan~add(route)
      do st over edgeSteps; plan~add(st); end
      outage = 'checkpoint handover; clients see an outage of the activation time'
      if svc~edge == 'DNS' then outage = outage 'plus up to' svc~ttlSec's of cached DNS'
      decisions~append(id':' outage)
    end
    decisions~append(id': move' src '('srcZone') ->' dst '('zone'):' pick[2])
    /* The source side is simulated here; the target side was simulated by its own arbitrator. */
    sim = srcArb~state~copy
    do st over srcSteps
      sim~apply(st, now)
      do v over sim~violations; plan~noteViolation(src':' v); end
    end
    do v over dstPlan~violations; plan~noteViolation(dst':' v); end
  end
  return plan

/* Place a main and its hot spare.  They must be on separate sites. */
::method addPair
  expose mus pairs
  use strict arg pair, mainMu, spareMu
  if \mus~hasIndex(mainMu) | \mus~hasIndex(spareMu) then raise syntax 93.900 array ('No such MU for' pair~name)
  if mus[mainMu]['ZONE'] == mus[spareMu]['ZONE'] then raise syntax 93.900 array (pair~name': main and spare must be on separate sites')
  r = .Directory~new; r['PAIR'] = pair; r['EPOCH'] = 1; r['NEXT'] = 3
  r['MAIN'] = pair~instance(1); r['MAINMU'] = mainMu
  r['SPARE'] = pair~instance(2); r['SPAREMU'] = spareMu
  pairs[pair~name] = r
  self~hold(mainMu, r['MAIN']); self~hold(spareMu, r['SPARE'])
  return self
/* Which MU answers a role address this minute. */
::method roleAt
  expose pairs
  use strict arg address
  parse var address name '.' role
  if \pairs~hasIndex(name) then return ''
  if role == 'main'  then return pairs[name]['MAINMU']
  if role == 'spare' then return pairs[name]['SPAREMU']
  return ''
::method epochOf
  expose pairs
  use strict arg name
  return pairs[name]['EPOCH']

/* Quorum has decided an MU is dead.  Every main on it fails over to its
   spare; every spare on it, or promoted away, is replaced on another site. */
::method muDown
  expose mus pairs decisions services
  use strict arg muId, now
  if \mus~hasIndex(muId) then raise syntax 93.900 array ('No MU' muId)
  mus[muId]['DOWN'] = .true
  plan = .ProvisionPlan~new
  plan~setPurpose('RECOVERY')
  decisions = .Array~new
  do name over pairs~allIndexes~sort
    r = pairs[name]; pair = r['PAIR']
    mainMu = r['MAINMU']; spareMu = r['SPAREMU']
    if mainMu \== muId & spareMu \== muId then iterate
    if mainMu == muId then do
      if mus[spareMu]['DOWN'] then do
        plan~noteViolation(name': main and spare are both down; nothing to promote')
        iterate
      end
      e = r['EPOCH'] + 1
      plan~add(.ClusterStep~new('FENCE_ROLE', r['SPARE'], muId 'is down (quorum)', spareMu, 'ROUTE',,,, 'raise' pair~mainAddress"'s epoch to" e '(for LDAP: IdentityPeerEpochAuthority~promote on' spareMu', sealing epoch' r['EPOCH'] 'at its last committed sequence);any answer from epoch' r['EPOCH'] '(the old main on' muId') is refused if it comes back', pair~mainAddress))
      plan~add(roleStep(pair, r['SPARE'], spareMu, pair~mainAddress, 'the spare becomes the main'))
      decisions~append(name':' pair~mainAddress 'moves to' spareMu '('mus[spareMu]['ZONE']'), epoch' e)
      newMainMu = spareMu
    end
    else newMainMu = mainMu
    /* A new spare, on a site other than the main's. */
    d = pair~instance(r['NEXT'])
    found = self~targetIn('', d, newMainMu, now, mus[newMainMu]['ZONE'], .true)
    if found == .nil then do
      plan~noteViolation(name': no MU on another site can take a new spare; running without one')
      decisions~append(name': NO SPARE - no other site can take one')
      iterate
    end
    dst = found[1]
    do st over found[2]~planned; plan~add(.ClusterStep~fromMachine(st, dst, 'TARGET')); end
    plan~add(.ClusterStep~new('CHECK_SERVING', d, 'the new spare must have caught up before it is named', dst, 'TARGET',,,, 'call' d~id 'on' dst 'directly over XTP;compare its replica generation (for LDAP: its peer origin sequence) with' pair~mainAddress"'s"))
    plan~add(roleStep(pair, d, dst, pair~spareAddress, 'a new hot spare on another site'))
    decisions~append(name':' pair~spareAddress 'is made on' dst '('mus[dst]['ZONE']')')
    do v over found[2]~violations; plan~noteViolation(dst':' v); end
  end
  /* Services that lived on the dead MU are restored elsewhere: same site
     first, then their home zone, then anywhere.  Restore only: what they
     were, from their saved state; TEMPORARY state starts afresh. */
  do id over services~allIndexes~sort
    s = services[id]
    if s['MU'] \== muId then iterate
    svc = s['SVC']; d = svc~demand
    found = .nil
    do z over .Array~of(mus[muId]['ZONE'], svc~homeZone, '')
      found = self~targetIn(z, d, muId, now, '', .true)
      if found \== .nil then leave
    end
    if found == .nil then do
      plan~noteViolation(id': no MU can restore it without displacing other work')
      decisions~append(id': DOWN with' muId '- no MU can restore it')
      iterate
    end
    dst = found[1]
    do st over found[2]~planned; plan~add(.ClusterStep~fromMachine(st, dst, 'TARGET')); end
    plan~add(.ClusterStep~new('CHECK_SERVING', d, 'prove the restored copy serves before anyone is sent to it', dst, 'TARGET',,,, 'call' svc~xtpService 'on' dst 'directly over XTP;compare the content digest with the fabric copy'))
    plan~add(.ClusterStep~new('ROUTE_SERVICE', d, muId 'is down (quorum)', dst, 'ROUTE',,,, 'register' svc~xtpService 'with' dst"'s XTP daemon;publish the route (LDAP);clients keep the same service address", svc~xtpService))
    if svc~edge == 'DNS' then
      plan~add(.ClusterStep~new('REPOINT_DNS', d, 'the public name' svc~dnsName 'names equipment', dst, 'EDGE',,,, 'point' svc~dnsName 'at' mus[dst]['ADDRESS']';changes public exposure, so it needs approval', ''))
    lost = ''
    if \d~deactivatable then lost = '; its TEMPORARY state is lost, it starts afresh'
    if d~stateWhere == 'CHECKPOINT' then lost = '; work since its last checkpoint is lost'
    decisions~append(id': restored from' muId 'on' dst '('mus[dst]['ZONE']')'lost)
    do v over found[2]~violations; plan~noteViolation(dst':' v); end
  end
  return plan

/* The whole cluster record, for the PlanRunner's snapshots: every MU with
   its ledger, what each holds, the services and the role pairs. */
::method snapshotLines
  expose mus services pairs
  r = .Array~new
  do id over mus~allIndexes~sort
    m = mus[id]
    r~append('MU|'id'|'m['ZONE']'|'m['ADDRESS']'|' || (m['DOWN'] == .true))
    do l over m['ARB']~snapshotLines; r~append('L|'id'|'l); end
    do d over m['HELD']; r~append('HELD|'id'|'d~toText); end
  end
  do id over services~allIndexes~sort
    s = services[id]; svc = s['SVC']
    r~append('SVC|'id'|'s['MU']'|'s['SINCE']'|'svc~xtpService'|'svc~edge'|'svc~dnsName'|'svc~ttlSec'|'svc~homeZone'|'svc~minResidenceSec)
    r~append('SVCD|'id'|'svc~demand~toText)
    do u over svc~rulesList; r~append('RULE|'id'|'u['ZONE']'|'u['FROM']'|'u['TO']'|'u['SHARE']); end
  end
  do name over pairs~allIndexes~sort
    p = pairs[name]
    spare = ''
    if p['SPARE'] \== .nil then spare = p['SPARE']~toText
    r~append('PAIR|'name'|'p['EPOCH']'|'p['NEXT']'|'p['MAINMU']'|'p['SPAREMU'])
    r~append('PAIRT|'name'|'p['PAIR']~selfRouting'|'p['PAIR']~template~toText)
    r~append('PAIRM|'name'|'p['MAIN']~toText)
    if spare \== '' then r~append('PAIRS|'name'|'spare)
  end
  return r
::method restoreFromLines
  expose mus services pairs
  use strict arg lines
  mus = .Directory~new; services = .Directory~new; pairs = .Directory~new
  ledger = .Directory~new
  do l over lines
    parse var l tag '|' a '|' rest
    select
      when tag == 'MU' then do
        parse var rest zone '|' address '|' down
        m = .Directory~new; m['ZONE'] = zone; m['ADDRESS'] = address; m['HELD'] = .Array~new; m['DOWN'] = (down == 1)
        m['ARB'] = .nil; mus[a] = m; ledger[a] = .Array~new
      end
      when tag == 'L' then ledger[a]~append(rest)
      when tag == 'HELD' then mus[a]['HELD']~append(.Demand~fromText(rest))
      when tag == 'SVC' then do
        parse var rest mu '|' since '|' xtp '|' edge '|' dns '|' ttl '|' home '|' minRes
        s = .Directory~new; s['MU'] = mu; s['SINCE'] = since
        s['ARGS'] = .Array~of(xtp, edge, dns, ttl, home, minRes); s['RULES'] = .Array~new
        services[a] = s
      end
      when tag == 'SVCD' then services[a]['DEMAND'] = .Demand~fromText(rest)
      when tag == 'RULE' then services[a]['RULES']~append(rest)
      when tag == 'PAIR' then do
        parse var rest epoch '|' next '|' mainMu '|' spareMu
        p = .Directory~new; p['EPOCH'] = epoch; p['NEXT'] = next; p['MAINMU'] = mainMu; p['SPAREMU'] = spareMu; p['SPARE'] = .nil
        pairs[a] = p
      end
      when tag == 'PAIRT' then do
        parse var rest selfR '|' tdemand
        pairs[a]['PAIR'] = .RolePair~new(a, .Demand~fromText(tdemand), selfR)
      end
      when tag == 'PAIRM' then pairs[a]['MAIN'] = .Demand~fromText(rest)
      when tag == 'PAIRS' then pairs[a]['SPARE'] = .Demand~fromText(rest)
      otherwise raise syntax 93.900 array ('Not a cluster record:' l)
    end
  end
  do id over mus~allIndexes
    arb = .MachineArbitrator~new(.MachineState~new(2, 1, 0))
    arb~restoreFromLines(ledger[id])
    mus[id]['ARB'] = arb
  end
  do id over services~allIndexes
    s = services[id]; g = s['ARGS']
    svc = .ServicePlacement~new(s['DEMAND'], g[1], g[2], g[3], g[4], g[5], g[6])
    do u over s['RULES']; parse var u z '|' f '|' t '|' sh; svc~rule(z, f, t, sh); end
    r = .Directory~new; r['SVC'] = svc; r['MU'] = s['MU']; r['SINCE'] = s['SINCE']
    services[id] = r
  end
  return self

/* An MU in the zone whose own arbitrator can take the demand without asking
   anything of the cluster.  Returns .Array~of(muId, machinePlan) or .nil. */
::method targetIn private
  expose mus
  use strict arg zone, d, src, now, avoidZone = '', restoreOnly = .false
  do id over mus~allIndexes~sort
    m = mus[id]
    if m['DOWN'] == .true | id == src then iterate
    if zone \== '' & m['ZONE'] \== zone then iterate
    if avoidZone \== '' & m['ZONE'] == avoidZone then iterate
    trial = m['ARB']~state~copy
    if d~deactivatable then trial~park(d)           /* its saved state may be activated there */
    demands = m['HELD']~copy; demands~append(d)
    p = m['ARB']~plan(demands, now, trial, restoreOnly)
    if \p~ok then iterate
    clean = .true
    do s over p~steps
      if s~kind == 'ASK_CLUSTER' | s~status == 'WAITING' then clean = .false
      if restoreOnly & s~status == 'PLANNED' & s~changesMachine & wordpos(s~kind, .ProvisionPlan~recoveryKinds) = 0 then clean = .false
    end
    if clean then return .Array~of(id, p)
  end
  return .nil

/* Record that a cluster step has been carried out. */
::method completed
  expose mus services pairs
  use strict arg step, now
  if \step~isA(.ClusterStep) then raise syntax 93.900 array ('Not a cluster step')
  d = step~demand; m = mus[step~mu]; arb = m['ARB']
  select
    when wordpos(step~kind, .ProvisionStep~kinds) > 0 & step~kind \== 'ASK_CLUSTER' then do
      if step~kind == 'ACTIVATE_TASK' & step~role == 'TARGET' & \arb~state~parked~hasIndex(d~id) then arb~state~park(d)
      arb~completed(step, now)
      if step~role == 'TARGET' & step~kind == 'ACTIVATE_TASK' then self~hold(step~mu, d)
      if step~role == 'SOURCE' & wordpos(step~kind, 'DEACTIVATE_TASK STOP_TASK') > 0 then do
        arb~state~unpark(d~id)                      /* the state now belongs to the target */
        call removeById m['HELD'], d~id
      end
    end
    when step~kind == 'ROUTE_SERVICE' | step~kind == 'ANNOUNCE_ROLE' then do
      parse value step~address with name '.' role
      if pairs~hasIndex(name) & (role == 'main' | role == 'spare') then do
        r = pairs[name]
        if role == 'main' then do
          dead = r['MAINMU']
          call removeById mus[dead]['HELD'], r['MAIN']~id    /* fenced; forgotten with its dead MU */
          r['MAIN'] = d; r['MAINMU'] = step~mu
          r['SPARE'] = .nil; r['SPAREMU'] = ''
        end
        else do
          if r['SPAREMU'] \== '' then call removeById mus[r['SPAREMU']]['HELD'], r['SPARE']~id
          r['SPARE'] = d; r['SPAREMU'] = step~mu; r['NEXT'] += 1
        end
      end
      else do
        old = services[d~id]['MU']
        if mus[old]['DOWN'] then call removeById mus[old]['HELD'], d~id
        services[d~id]['MU'] = step~mu
        services[d~id]['SINCE'] = now
        if step~mu \== old then self~hold(step~mu, d)
      end
    end
    when step~kind == 'FENCE_ROLE' then do
      parse value step~address with name '.' .
      pairs[name]['EPOCH'] += 1
    end
    otherwise nop
  end
  return self

::routine inArray
  use strict arg a, item
  do x over a; if x == item then return .true; end
  return .false

::routine indexById
  use strict arg a, id
  do i = 1 to a~items; if a[i]~id == id then return i; end
  return 0

::routine removeById
  use strict arg a, id
  i = indexById(a, id)
  if i > 0 then a~delete(i)
  return

/* How a role address moves.  An ordinary pair publishes the route through
   LDAP.  The pair that carries the routes (LDAP itself) cannot: the move is
   announced directly to every XTP daemon, signed, and each daemon rewrites
   its bootstrap file (Tom Dyer, 2026-11-25). */
::routine roleStep
  use strict arg pair, d, mu, address, why
  if pair~selfRouting then
    return .ClusterStep~new('ANNOUNCE_ROLE', d, why, mu, 'ROUTE',,,, 'sign the new' pair~name 'role record (main, spare, epoch, version, seeds) with the role authority;send it directly to every live XTP daemon (unicast: XTP has no qualified multicast);each daemon checks the signature, the trusted key in its bootstrap file and that the record is newer, then rewrites its bootstrap file', address)
  return .ClusterStep~new('ROUTE_SERVICE', d, why, mu, 'ROUTE',,,, 'register' address 'with' mu"'s XTP daemon;publish the route (LDAP);clients keep" address, address)
