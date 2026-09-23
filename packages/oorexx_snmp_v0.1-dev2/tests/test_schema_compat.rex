text='{"schema":"snmp.implementation.map/0.1","name":"compat","objects":[{"name":"x","oid":"1.3.6.1.4.1.1.0","kind":"scalar","syntax":"INTEGER","access":"read-only"}]}'
map=.SnmpImplementationMapLoader~new~loadText(text)
if map~object('x')==.nil then do; say 'FAIL v0.1 schema compatibility'; exit 1; end
say 'PASS implementation-map /0.1 compatibility'
exit 0
::requires '../src/Snmp.cls'
