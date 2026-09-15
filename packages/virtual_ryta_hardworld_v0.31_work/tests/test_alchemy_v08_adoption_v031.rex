say 'RYTA ALCHEMY V0.8 ADOPTION V0.31 START'
ring = .CryptoMacKeyRing~new
ring~addKey('ryta-v031-adoption', '00112233445566778899aabbccddeeff')
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
options = .directory~new
options['SEALER'] = sealer
options['CAPABILITY_AUTHORITY'] = authority
ryta = .VirtualRYTA~new(options)
adoption = .AlchemyAdoptionVerifier~verify(ryta, 'STANDARD')
call AssertTrue adoption~ok, 'VirtualRYTA STANDARD adoption'
call AssertEqual 0, adoption~warnings~items, 'no migration warning'
construction = ryta~alchemyConstructionProvenance
call AssertEqual 'INIT', construction['entrypoint'], 'preferred construction entrypoint'
call AssertEqual '0.8', construction['base_version'], 'Alchemy v0.8 base version'
base = ryta~alchemyBaseState
metadata = base['metadata']
call AssertEqual '0.31-work', metadata['PACKAGE_VERSION'], 'RYTA package version metadata'
call AssertTrue metadata['STANDARDS']~pos('ALCHEMY-HOUSE-OBJECT-0.8') > 0, 'v0.8 house standard declared'
call AssertTrue metadata['DESIGN_LIMITATIONS']~pos('does not confer') > 0, 'authority limitation retained'
call AssertTrue base['cooperative_interposition_available'] = .false, 'plain RYTA has no external coordinator by default'
say '  adoption=' || adoption~level || ' construction=' || construction['entrypoint'] || '/base-' || construction['base_version']
say 'RYTA ALCHEMY V0.8 ADOPTION V0.31: OK'
exit 0
::routine AssertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0
::routine AssertEqual
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0
::requires '../VirtualRYTA.cls'
::requires 'AlchemySecurity.cls'
::requires 'AlchemyAdoption.cls'
