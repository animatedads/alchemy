/* Architecture Tom Dyer; implementation ChatGPT (GPT-6.2).
   Referee-side only. Grammar, static validity and duplicate handling.
   Dynamic movement, convoy routes, support matching and combat are adjudication. */
::requires 'DiplomacyBoard.cls'

::class DiplomacyUnit public
::attribute owner get
::attribute unitType get
::attribute location get
::method init
  expose owner unitType location
  use strict arg owner, unitType, location
  owner = owner~upper
  unitType = unitType~upper
  location = location~upper
::method module_version class
  return '0.1-dev2'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev2'
::method module_lastChanged
  return '2026-11-26'

::class DiplomacyOrder public
::attribute raw get
::attribute unitType
::attribute origin
::attribute action
::attribute targetType
::attribute targetOrigin
::attribute destination
::attribute viaConvoy
::attribute reason
::attribute resolvedDestination
::method init
  expose raw unitType origin action targetType targetOrigin destination viaConvoy reason resolvedDestination
  use strict arg raw
  unitType = ''
  origin = ''
  action = ''
  targetType = ''
  targetOrigin = ''
  destination = ''
  viaConvoy = .false
  reason = 'SYNTAX'
  resolvedDestination = ''
::method valid
  expose reason
  return reason == ''
::method module_version class
  return '0.1-dev2'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev2'
::method module_lastChanged
  return '2026-11-26'

::class DiplomacyOrderParser public
::method init
  expose board
  use strict arg board
::method module_version class
  return '0.1-dev4r3'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4r3'
::method module_lastChanged
  return '2026-11-26'

::method isLocation
  use strict arg loc
  parse var loc province '/' coast
  if province~length \= 3 then return .false
  if province~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ') \= 0 then return .false
  if loc == province then return .true
  if coast~length \= 2 then return .false
  return coast~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ') = 0

::method parseOrder
  use strict arg raw, phase = 'MOVEMENT'
  order = .DiplomacyOrder~new(raw)
  phase = phase~upper
  text = raw~upper~translate(' ', '09'x)
  text = text~changestr('-', ' - ')~space
  count = words(text)
  parse var text first second third fourth fifth sixth seventh extra
  if phase == 'ADJUSTMENT' then do
    if first == 'WAIVE' then do
      if count = 1 then do
        order~action = 'WAIVE'
        order~reason = ''
      end
      return order
    end
    if wordpos(first,'BUILD DISBAND') = 0 then return order
    if wordpos(second,'A F') = 0 then return order
    if \self~isLocation(third) then return order
    order~action = first
    order~unitType = second
    order~origin = third
    if count = 3 then order~reason = ''
    return order
  end
  if wordpos(first,'A F') = 0 then return order
  if \self~isLocation(second) then return order
  order~unitType = first
  order~origin = second
  if phase == 'RETREAT' then do
    if third == 'D' then do
      if count = 3 then do
        order~action = 'DISBAND'
        order~reason = ''
      end
      return order
    end
    if third == 'R' then do
      if count = 4 then if self~isLocation(fourth) then do
        order~action = 'RETREAT'
        order~destination = fourth
        order~reason = ''
      end
    end
    return order
  end
  if phase \== 'MOVEMENT' then return order
  select
    when third == 'H' then do
      if count = 3 then do
        order~action = 'HOLD'
        order~reason = ''
      end
    end
    when third == '-' then do
      if \self~isLocation(fourth) then return order
      if count \= 4 then do
        if count \= 6 then return order
        if fifth sixth \== 'VIA CONVOY' then return order
        order~viaConvoy = .true
      end
      order~action = 'MOVE'
      order~destination = fourth
      order~reason = ''
    end
    when wordpos(third,'S C') > 0 then do
      if wordpos(fourth,'A F') = 0 then return order
      if \self~isLocation(fifth) then return order
      if third == 'S' then do
        if count = 5 then order~action = 'SUPPORT_HOLD'
        else if count = 7 then order~action = 'SUPPORT_MOVE'
        else return order
      end
      else do
        if count \= 7 then return order
        order~action = 'CONVOY'
      end
      if count = 7 then do
        if sixth \== '-' then return order
        if \self~isLocation(seventh) then return order
        order~destination = seventh
      end
      order~targetType = fourth
      order~targetOrigin = fifth
      order~reason = ''
    end
    otherwise nop
  end
  return order

/* Get the fleet's possible destination nodes for one province.
   Never published to the player. */
::method fleetDestinations
  expose board
  use strict arg origin, destination
  province = board~provinceOf(destination)
  choices = .array~new
  do nodeCode over board~neighbours(origin,'F')
    if board~provinceOf(nodeCode) == province then choices~append(nodeCode)
  end
  return choices

/* No missing-coast inference. Validate the textual reference, not an
   imagined intended destination. Province occupancy remains separate. */
::method coastReason
  expose board
  use strict arg location, unitType
  province = board~provinceOf(location)
  if unitType == 'A' then do
    if location \== province then return 'BAD_COAST'
    return ''
  end
  if location \== province then do
    node = board~node(location)
    if node == .nil then return 'BAD_COAST'
    if node['KIND'] \== 'split' then return 'BAD_COAST'
    return ''
  end
  node = board~node(province)
  if node == .nil then return ''
  if node['KIND'] == 'coast' then if board~neighbours(province,'F')~items = 0 then return 'NO_COAST'
  return ''

::method resolveDestination
  expose board
  use strict arg order, unit
  destination = order~destination
  province = board~provinceOf(destination)
  coastIssue = self~coastReason(destination,unit~unitType)
  if coastIssue \== '' then return coastIssue
  node = board~node(destination)
  if node == .nil then return 'NOT_ADJACENT'
  if province == board~provinceOf(unit~location) then return 'NOT_ADJACENT'
  if unit~unitType == 'A' then do
    if node['KIND'] == 'sea' then return 'NOT_ADJACENT'
    order~resolvedDestination = province
    if order~viaConvoy then do
      if province == board~provinceOf(unit~location) then return 'BAD_CONVOY'
      if board~node(unit~location)['KIND'] \== 'coast' then return 'BAD_CONVOY'
      if node['KIND'] \== 'coast' then return 'BAD_CONVOY'
      return ''
    end
    if board~adjacent(unit~location,province,'A') then return ''
    if order~action == 'MOVE' then do
      if board~node(unit~location)['KIND'] == 'coast' then if node['KIND'] == 'coast' then return ''
    end
    return 'NOT_ADJACENT'
  end
  if order~viaConvoy then return 'BAD_CONVOY'
  if destination \== province then do
    if \board~adjacent(unit~location,destination,'F') then return 'BAD_COAST'
    order~resolvedDestination = destination
    return ''
  end
  if \board~adjacent(unit~location,destination,'F') then return 'NOT_ADJACENT'
  order~resolvedDestination = destination
  return ''

/* Validate only using the supplied referee state. Units keyed by province;
   retreatOptions keyed by dislodged province. No pre-deadline checks exposed. */
::method validate
  expose board
  use strict arg order, power, units, retreatOptions = (.directory~new), ownership = (.directory~new)
  if \order~valid then return order
  if order~action == 'WAIVE' then return order
  province = board~provinceOf(order~origin)
  if order~action == 'BUILD' then do
    order~reason = self~validateBuild(order,power,units,ownership)
    return order
  end
  if \units~hasIndex(province) then do
    order~reason = 'NO_UNIT'
    return order
  end
  unit = units[province]
  if unit~owner \== power then do
    order~reason = 'NOT_OWN_UNIT'
    return order
  end
  if unit~unitType \== order~unitType then do
    order~reason = 'WRONG_TYPE'
    return order
  end
  order~reason = self~coastReason(order~origin,unit~unitType)
  if \order~valid then return order
  if order~origin \== unit~location then do
    order~reason = 'BAD_COAST'
    return order
  end
  select
    when order~action == 'HOLD' then nop
    when order~action == 'DISBAND' then nop
    when order~action == 'MOVE' then order~reason = self~resolveDestination(order,unit)
    when order~action == 'RETREAT' then do
      order~reason = self~resolveDestination(order,unit)
      if order~valid then do
        if \retreatOptions~hasIndex(province) then order~reason = 'NOT_RETREAT_OPTION'
        else if \retreatOptions[province]~hasItem(order~resolvedDestination) then order~reason = 'NOT_RETREAT_OPTION'
      end
    end
    when wordpos(order~action,'SUPPORT_HOLD SUPPORT_MOVE CONVOY') > 0 then order~reason = self~validateAssistance(order,unit,units)
    otherwise order~reason = 'SYNTAX'
  end
  return order

::method validateAssistance
  expose board
  use strict arg order, unit, units
  targetProvince = board~provinceOf(order~targetOrigin)
  reasonCode = 'BAD_SUPPORT'
  if order~action == 'CONVOY' then reasonCode = 'BAD_CONVOY'
  if \units~hasIndex(targetProvince) then return reasonCode
  target = units[targetProvince]
  if target~unitType \== order~targetType then return reasonCode
  coastIssue = self~coastReason(order~targetOrigin,target~unitType)
  if coastIssue \== '' then return coastIssue
  if order~targetOrigin \== target~location then return 'BAD_COAST'
  if order~action \== 'SUPPORT_HOLD' then do
    coastIssue = self~coastReason(order~destination,target~unitType)
    if coastIssue \== '' then return coastIssue
  end
  if order~action == 'CONVOY' then do
    if unit~unitType \== 'F' then return reasonCode
    if board~node(unit~location)['KIND'] \== 'sea' then return reasonCode
    if target~unitType \== 'A' then return reasonCode
    if board~node(target~location)['KIND'] \== 'coast' then return reasonCode
    dest = board~node(order~destination)
    if dest == .nil then return reasonCode
    if dest['KIND'] \== 'coast' then return reasonCode
    if targetProvince == order~destination then return reasonCode
    return ''
  end
  if targetProvince == board~provinceOf(unit~location) then return reasonCode
  if order~action == 'SUPPORT_HOLD' then destination = targetProvince
  else destination = order~destination
  destProvince = board~provinceOf(destination)
  if board~node(destination) == .nil then return reasonCode
  if unit~unitType == 'A' then do
    if board~adjacent(unit~location,destProvince,'A') then return ''
  end
  else if self~fleetDestinations(unit~location,destProvince)~items > 0 then return ''
  return reasonCode

::method validateBuild
  expose board
  use strict arg order, power, units, ownership
  province = board~provinceOf(order~origin)
  node = board~node(province)
  if node == .nil then return 'BAD_BUILD'
  if node['HOME'] \== power then return 'BAD_BUILD'
  if \ownership~hasIndex(province) then return 'BAD_BUILD'
  if ownership[province] \== power then return 'BAD_BUILD'
  if units~hasIndex(province) then return 'BAD_BUILD'
  coastIssue = self~coastReason(order~origin,order~unitType)
  if coastIssue \== '' then return coastIssue
  if order~unitType == 'F' then if node['KIND'] \== 'coast' then return 'BAD_BUILD'
  order~resolvedDestination = order~origin
  return ''

/* Keep verbatim lines including superseded orders. No validation feedback is
   returned to a player. Called only when the referee locks the orders. */
::method parseOrders
  expose board
  use strict arg lines, phase, power, units, retreatOptions = (.directory~new), ownership = (.directory~new)
  orders = .array~new
  latest = .directory~new
  do raw over lines
    order = self~parseOrder(raw,phase)
    order = self~validate(order,power,units,retreatOptions,ownership)
    orders~append(order)
    if phase~upper == 'ADJUSTMENT' then do
      if order~action == 'WAIVE' then iterate
      if order~origin == '' then iterate
      province = board~provinceOf(order~origin)
      if order~action == 'BUILD' then iterate
      if units~hasIndex(province) then do
        if units[province]~owner \== power then iterate
        key = 'UNIT:'province
      end
      else iterate
    end
    else do
      if order~origin == '' then iterate
      province = board~provinceOf(order~origin)
      if \units~hasIndex(province) then iterate
      if units[province]~owner \== power then iterate
      key = 'UNIT:'province
    end
    if latest~hasIndex(key) then latest[key]~reason = 'SUPERSEDED'
    latest[key] = order
  end
  return orders
