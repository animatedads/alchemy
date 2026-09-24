catalog=.CommonParts~standardBenchSet
checked=0
do key over catalog
  part=catalog[key]
  do role over part~materials
    materialId=part~materials[role]
    if materialId=.nil | materialId='' then iterate
    m=.CommonMaterials~byId(materialId)
    if m=.nil then do
      say 'FAIL unresolved material:' part~id role materialId
      exit 1
    end
    checked+=1
  end
end
say 'PASS material reference audit' checked 'references'
exit 0
::requires 'PartsCatalog.cls'
