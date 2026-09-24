ids=.array~of('GAAS-GENERIC','OPTICAL-GLASS-GENERIC','AL-ANODIZED-GENERIC','CU-C110-REFERENCE')
do id over ids
 if .CommonMaterials~byId(id)=.nil then do; say 'FAIL missing laser material' id; exit 1; end
end
say 'PASS laser material stack'
exit 0
::requires 'MaterialsCatalog.cls'
