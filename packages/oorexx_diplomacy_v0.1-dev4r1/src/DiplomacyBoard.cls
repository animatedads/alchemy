/* Standard Diplomacy map; province occupancy and fleet coast graph are separate. */
::class DiplomacyBoard public
::method init
  expose nodes provinces
  use strict arg path
  nodes = .directory~new
  provinces = .directory~new
  input = .stream~new(path)
  if input~open('READ') \= 'READY:' then raise syntax 93.900 array('Cannot open map:' path)
  do while input~lines > 0
    line = input~linein
    if line = '' then iterate
    if left(line,1) = '#' then iterate
    parse var line code '|' name '|' kind '|' home '|' army '|' fleet
    if nodes~hasIndex(code) then raise syntax 93.900 array('Duplicate map node:' code)
    entry = .directory~new
    entry['CODE'] = code
    entry['NAME'] = name
    entry['KIND'] = kind
    entry['HOME'] = home
    entry['ARMY'] = army~space
    entry['FLEET'] = fleet~space
    nodes[code] = entry
    if kind \= 'split' then provinces[code] = entry
  end
  input~close

::method module_version class
  return '0.1-dev2'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev2'
::method module_lastChanged
  return '2026-11-26'
::method provinceCodes
  expose provinces
  return provinces~allIndexes~sort
::method nodeCodes
  expose nodes
  return nodes~allIndexes~sort
::method provinceOf
  use strict arg code
  parse upper var code province '/' .
  return province
::method node
  expose nodes
  use strict arg code
  code = code~upper
  if \nodes~hasIndex(code) then return .nil
  return nodes[code]~copy
::method supplyCentres
  expose provinces
  centres = .array~new
  do code over self~provinceCodes
    if provinces[code]['HOME'] \= '-' then centres~append(code)
  end
  return centres
::method neighbours
  expose nodes
  use strict arg code, unitType
  code = code~upper
  if \nodes~hasIndex(code) then return .array~new
  select
    when unitType~upper = 'A' then key = 'ARMY'
    when unitType~upper = 'F' then key = 'FLEET'
    otherwise raise syntax 93.900 array('Invalid unit type:' unitType)
  end
  values = .array~new
  do i = 1 to words(nodes[code][key])
    values~append(word(nodes[code][key],i))
  end
  return values~sort
::method adjacent
  use strict arg origin, destination, unitType
  return self~neighbours(origin,unitType)~hasItem(destination~upper)
