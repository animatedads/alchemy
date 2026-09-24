ids=.array~of('BUTYL-BLADDER-GENERIC','POLYESTER-REINFORCEMENT-GENERIC','RUGBY-COVER-ELASTOMER-GENERIC','VALVE-RUBBER-GENERIC','AIR-20C')
do id over ids
  if .CommonMaterials~byId(id)=.nil then do
    say 'FAIL missing rugby material' id
    exit 1
  end
end
say 'PASS rugby ball material stack' ids~items 'materials'
exit 0
::requires 'MaterialsCatalog.cls'
