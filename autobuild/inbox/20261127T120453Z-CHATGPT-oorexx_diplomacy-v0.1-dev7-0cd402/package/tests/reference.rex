/* Independent map cross-check. Reference transcription from standard.map,
   Git blob 620fa3a81acb4c0021bd2cd5aec3628b66b373a3 (see README). */
board = .DiplomacyBoard~new('data/standard.source')
ref = .directory~new
input = .stream~new('evidence/reference-edges.txt')
if input~open('READ') \== 'READY:' then exit 2
do while input~lines > 0
  parse value input~linein with kind loc adjacency
  ref[loc~upper] = .array~of(kind,loc,adjacency)
end
input~close
checks = 0
failures = 0
edges = 0
call check ref~items = 82,'81 graph nodes plus Switzerland'
do loc over ref~allIndexes~sort
  entry = ref[loc]
  if entry[1] == 'SHUT' then do
    call check board~node(loc) == .nil,'impassable' loc
    iterate
  end
  node = board~node(loc)
  call check node \== .nil,'exists' loc
  if node == .nil then iterate
  kind = entry[1]
  select
    when loc~pos('/') > 0 then expectedKind = 'split'
    when kind == 'WATER' then expectedKind = 'sea'
    when kind == 'LAND' then expectedKind = 'land'
    otherwise expectedKind = 'coast'
  end
  call check node['KIND'] == expectedKind,'type' loc
  army = .directory~new
  fleet = .directory~new
  do dest over entry[3]~subWords
    destCode = dest~upper
    province = board~provinceOf(destCode)
    if kind \== 'WATER' then if loc == board~provinceOf(loc) then do
      if wordpos(ref[province][1],'WATER SHUT') = 0 then army[province] = .true
    end
    if wordpos(kind,'WATER COAST') > 0 then if entry[2] == entry[2]~upper then do
      if dest == destCode then if wordpos(ref[destCode][1],'WATER COAST') > 0 then do
        if ref[destCode][2] == ref[destCode][2]~upper then fleet[destCode] = .true
      end
    end
  end
  call check board~neighbours(loc,'A')~items = army~items,'army count' loc
  call check board~neighbours(loc,'F')~items = fleet~items,'fleet count' loc
  do dest over army~allIndexes~sort
    call check board~adjacent(loc,dest,'A'),'army edge' loc dest
    edges += 1
  end
  do dest over fleet~allIndexes~sort
    call check board~adjacent(loc,dest,'F'),'fleet edge' loc dest
    edges += 1
  end
end
call check edges = 504,'504 reference edges'
homes = .directory~new
homes['AUS'] = 'BUD TRI VIE'
homes['ENG'] = 'EDI LON LVP'
homes['FRA'] = 'BRE MAR PAR'
homes['GER'] = 'BER KIE MUN'
homes['ITA'] = 'NAP ROM VEN'
homes['RUS'] = 'MOS SEV STP WAR'
homes['TUR'] = 'ANK CON SMY'
homes['N'] = 'BEL BUL DEN GRE HOL NWY POR RUM SER SPA SWE TUN'
centres = 0
do power over homes~allIndexes~sort
  do loc over homes[power]~subWords
    call check board~node(loc)['HOME'] == power,'home' power loc
    centres += 1
  end
end
call check centres = board~supplyCentres~items,'all supply centres accounted for'
input = .stream~new('data/initial-1901.source')
if input~open('READ') \== 'READY:' then exit 2
occupied = .directory~new
do while input~lines > 0
  line = input~linein
  if left(line,1) == '#' then iterate
  parse var line power '|' unitType '|' loc
  province = board~provinceOf(loc)
  call check \occupied~hasIndex(province),'unique occupancy' loc
  occupied[province] = .true
  call check board~node(province)['HOME'] == power,'initial home' power loc
  call check board~neighbours(loc,unitType)~items > 0,'initial terrain' loc unitType
end
input~close
call check occupied~items = 22,'22 initial units'
say 'Reference checks:' checks 'Failures:' failures 'Edges:' edges
exit (failures > 0)
check: procedure expose checks failures
  use strict arg ok, description
  checks += 1
  if \ok then do
    failures += 1
    say 'FAIL:' description
  end
  return
::requires 'src/DiplomacyBoard.cls'
