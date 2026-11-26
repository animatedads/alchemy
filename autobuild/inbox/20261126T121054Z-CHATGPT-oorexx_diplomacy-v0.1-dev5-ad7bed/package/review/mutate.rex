/* Mutation stress test around known convoy paradoxes.
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Usage: rexx review/mutate.rex iterations seed fixtureFile caseIdPrefix...
   Loads the named fixture cases, applies 1-3 random mutations to one at a time
   (drop an order, change an owner, add random units, replace an order), resolves
   it, and checks: no exception, conservation, insertion-order determinism,
   dislodged provinces reoccupied. Failing positions are printed as fixtures. */
parse arg muTotal muSeed muFile muPrefixes
call random 1, 2, muSeed
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
bases = .array~new
input = .stream~new(muFile)
if input~open('READ') \== 'READY:' then exit 2
muKeep = .false
do while input~lines > 0
  line = input~linein~strip
  parse var line command payload
  if command == 'CASE' then do
    muKeep = .false
    do prefix over muPrefixes~space~makeArray(' ')
      if payload~word(1)~left(prefix~length) == prefix then muKeep = .true
    end
    if muKeep then do
      current = .directory~new
      current['ID'] = payload~word(1)
      current['UNITS'] = .array~new
      current['ORDERS'] = .array~new
    end
  end
  if \muKeep then iterate
  if command == 'UNIT' then current['UNITS']~append(payload)
  if command == 'ORDER' then current['ORDERS']~append(payload)
  if command == 'END' then bases~append(current)
end
input~close
say 'Base positions:' bases~items
fleetSpots = .array~new
armySpots = .array~new
do code over board~nodeCodes
  node = board~node(code)
  if node['FLEET'] \== '' then fleetSpots~append(code)
  if node['KIND'] \== 'split' then if node['KIND'] \== 'sea' then if node['ARMY'] \== '' then armySpots~append(code)
end
muErrors = 0
muFailures = 0
muParadox = 0
do muCase = 1 to muTotal
  base = bases[random(1, bases~items)]
  unitLines = base['UNITS']~copy
  orderLines = base['ORDERS']~copy
  do muStep = 1 to random(1, 3)
    kind = random(1, 4)
    select
      when kind = 1 then if orderLines~items > 0 then orderLines~delete(random(1, orderLines~items))
      when kind = 2 then do
        pickIdx = random(1, unitLines~items)
        parse value unitLines[pickIdx] with uOwner uType uLoc
        newOwner = powers[random(1, 7)]
        unitLines[pickIdx] = newOwner uType uLoc
        do oIdx = 1 to orderLines~items
          parse value orderLines[oIdx] with oOwner oType oLoc oRest
          if oType == uType then if oLoc == uLoc then orderLines[oIdx] = newOwner oType oLoc oRest
        end
      end
      when kind = 3 then do
        do addIdx = 1 to random(1, 3)
          if random(1, 2) = 1 then do
            spot = fleetSpots[random(1, fleetSpots~items)]
            uType = 'F'
          end
          else do
            spot = armySpots[random(1, armySpots~items)]
            uType = 'A'
          end
          taken = .false
          do uLine over unitLines
            if board~provinceOf(uLine~word(3)) == board~provinceOf(spot) then taken = .true
          end
          if taken then iterate
          owner = powers[random(1, 7)]
          unitLines~append(owner uType spot)
          next = board~neighbours(spot, uType)
          if next~items > 0 then orderLines~append(owner uType spot '-' next[random(1, next~items)])
        end
      end
      otherwise if orderLines~items > 0 then do
        oIdx = random(1, orderLines~items)
        parse value orderLines[oIdx] with oOwner oType oLoc .
        next = board~neighbours(oLoc, oType)
        if next~items > 0 & random(1, 2) = 1 then orderLines[oIdx] = oOwner oType oLoc '-' next[random(1, next~items)]
        else orderLines[oIdx] = oOwner oType oLoc 'H'
      end
    end
  end
  units = .directory~new
  do uLine over unitLines
    parse var uLine uOwner uType uLoc
    units[board~provinceOf(uLoc)] = .DiplomacyUnit~new(uOwner, uType, uLoc)
  end
  orders = .directory~new
  do oLine over orderLines
    parse var oLine oOwner oRaw
    if \orders~hasIndex(oOwner) then orders[oOwner] = .array~new
    orders[oOwner]~append(oRaw)
  end
  first = safeMovement(judge, units, orders)
  if \first~isA(.DiplomacyMovement) then do
    muErrors += 1
    call muReport base['ID'], first, unitLines, orderLines
    iterate
  end
  if first~paradoxes~items > 0 then muParadox += 1
  problems = .array~new
  second = safeMovement(judge, reversed(units), reversed(orders))
  if \second~isA(.DiplomacyMovement) then problems~append('exception on reversed input')
  else if fingerprint(first) \== fingerprint(second) then problems~append('insertion-order dependence')
  if first~units~items + first~dislodged~items \= units~items then problems~append('conservation')
  do province over first~dislodged~allIndexes~sort
    if \first~units~hasIndex(province) then problems~append('dislodged province empty:' province)
  end
  if problems~items > 0 then do
    muFailures += 1
    call muReport base['ID'], problems~makeString('L', '; '), unitLines, orderLines
  end
end
say 'Mutated positions:' muTotal 'seed' muSeed 'with paradox' muParadox 'exceptions' muErrors 'invariant failures' muFailures
exit (muErrors + muFailures > 0)

muReport:
  use arg mrBase, mrWhat, mrUnits, mrOrders
  say 'MUTATE FAIL from' mrBase':' mrWhat
  say 'CASE MUT-'mrBase
  do mrLine over mrUnits
    say 'UNIT' mrLine
  end
  do mrLine over mrOrders
    say 'ORDER' mrLine
  end
  say 'END'
  return

::routine safeMovement
  use strict arg judge, units, orders
  signal on syntax name smTrapped
  return judge~movement(units, orders)
smTrapped:
  say 'Trapped: rc' rc 'sigl' sigl condition('C') condition('D')
  return 'SYNTAX' condition('O')['MESSAGE']

::routine reversed
  use strict arg entries
  out = .directory~new
  keyList = entries~allIndexes~sort
  do idx = keyList~items to 1 by -1
    value = entries[keyList[idx]]
    if value~isA(.array) then value = value~copy
    out[keyList[idx]] = value
  end
  return out

::routine fingerprint
  use strict arg movement
  buf = .mutablebuffer~new
  do province over movement~units~allIndexes~sort
    unit = movement~units[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  do province over movement~dislodged~allIndexes~sort
    buf~append('D' province movement~dislodged[province][2]';')
  end
  do record over movement~published
    buf~append(record~makeString('L','|')';')
  end
  return buf~string

::requires 'src/DiplomacyAdjudicator.cls'
