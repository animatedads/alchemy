parse source . . here
base=filespec('L',here)
loader=.SnmpImplementationMapLoader~new
baseMap=loader~loadFile(base||'../maps/ietf_minimal.json')
vendor=loader~loadFile(base||'../maps/example_vendor_sensor.json')
site=loader~loadFile(base||'../maps/site_override.json')
initial=.directory~new
initial['1.3.6.1.2.1.1.5.0']='stale-base-name'
initial['1.3.6.1.4.1.99999.99.5.0']='router-a'
initial['1.3.6.1.4.1.99999.1.1.0']='42'
initial['1.3.6.1.4.1.99999.1.2.0']='1'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,baseMap)
router=.SnmpAgent~new('router-a',session,baseMap)
router~adopt(vendor)~adopt(site)
if router~sysName<>'router-a' then do; say 'FAIL site override did not replace base OID'; exit 1; end
if baseMap~resolveOid('1.3.6.1.2.1.1.5.0')<>.nil then do; say 'FAIL stale reverse OID survived override'; exit 1; end
if router~temperature<>'42' then do; say 'FAIL vendor property missing'; exit 1; end
if router~fanMode<>'auto' then do; say 'FAIL vendor enum missing'; exit 1; end
router~fanMode='full'
if router~fanMode<>'full' then do; say 'FAIL adopted setter missing'; exit 1; end
if baseMap~layers~items<>3 then do; say 'FAIL map layers'; exit 1; end
say 'PASS layered map adoption and override cleanup'
exit 0

::requires '../src/Snmp.cls'
