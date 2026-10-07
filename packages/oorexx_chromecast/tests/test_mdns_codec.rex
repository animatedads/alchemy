call main
exit 0
main:
  q=.CastDiscovery~queryPacket
  call assert length(q)>20,'query built'
  call assert pos('_googlecast',q)>0,'query contains service label'

  /* Synthetic complete DNS-SD response with compression-free names. */
  service='_googlecast._tcp.local'
  instance='Living Room._googlecast._tcp.local'
  host='castbox.local'
  header='000084000000000400000000'x
  ptr=.MdnsNameCodec~encode(service)||'000c000100000078'x||u16(length(.MdnsNameCodec~encode(instance)))||.MdnsNameCodec~encode(instance)
  srvdata='000000001f49'x||.MdnsNameCodec~encode(host)
  srv=.MdnsNameCodec~encode(instance)||'0021000100000078'x||u16(length(srvdata))||srvdata
  txtdata=txt('id=abc123')||txt('fn=Living Room')||txt('md=Chromecast')
  txtr=.MdnsNameCodec~encode(instance)||'0010000100000078'x||u16(length(txtdata))||txtdata
  adata='c0a80132'x
  ar=.MdnsNameCodec~encode(host)||'0001000100000078'x||u16(length(adata))||adata
  packet=header||ptr||srv||txtr||ar
  services=.CastDiscovery~servicesFromPacket(packet)
  call assert services~items=1,'one service projected'
  s=services[1]
  call assert s~friendlyName='Living Room','friendly name'
  call assert s~model='Chromecast','model'
  call assert s~deviceId='abc123','device id'
  call assert s~port=8009,'port'
  call assert s~primaryAddress='192.168.1.50','IPv4 address'
  say 'PASS mDNS Chromecast discovery codec'
  return
u16:
  use strict arg n
  return d2c((n%256)//256)||d2c(n//256)
txt:
  use strict arg s
  return d2c(length(s))||s
assert:
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return
::requires '../src/CastV2.cls'
::requires '../src/CastDiscovery.cls'
