/* Memory Fabric XTP dev34 protected-message read adapter.
 * Only a native XtpNamedAcceptedSocket from a trusted service listener is
 * admissible. The key principal is revalidated through the live local
 * XtpServiceKeys registry on EVERY MemoryFabric read/page validation.
 * No message-supplied principal, KEY token, route, or ACK grants authority.
 */

::class MemoryXtp34KeyAuthenticator public
::method init
  expose keys clock service
  use strict arg keyRegistry, trustedClock, memoryService
  if keyRegistry==.nil | trustedClock==.nil then raise syntax 88.900 array('local keys and trusted clock required')
  if \keyRegistry~hasMethod('LIST') | \trustedClock~hasMethod('EPOCHSECONDS') then
    raise syntax 88.900 array('key registry/clock capability missing')
  keys=keyRegistry; clock=trustedClock; service=memoryService~string~strip
  if service='' then raise syntax 88.900 array('memory service required')

::method identityFor
  expose keys clock service
  use strict arg transportProof
  signal on syntax name denied
  signal on error name denied
  signal on failure name denied
  /* XTP 34's native listener checks protection; this rejects clear or
   * authenticate-only messages before any block/ACL operation. */
  if transportProof==.nil then return .nil
  if \transportProof~isA(.XtpNamedAcceptedSocket) then return .nil
  if transportProof~serviceName<>service then return .nil
  if transportProof~protection<>'encrypt' then return .nil
  kid=transportProof~keyId; principal=transportProof~keyPrincipal
  if \kid~isA(.String) | \principal~isA(.String) then return .nil
  if kid~length<>16 | kid~verify('0123456789abcdefABCDEF')<>0 then return .nil
  if principal='' | principal='-' | principal~length>128 then return .nil
  seconds=clock~epochSeconds
  if \datatype(seconds,'W') | seconds<0 then return .nil
  listing=keys~list
  if \listing~isA(.Array) then return .nil
  do record over listing
    if \record~isA(.Directory) then iterate
    if record['SERVICE']<>service then iterate
    if record['KEYID']==.nil then iterate
    if record['KEYID']~upper<>kid~upper then iterate
    if record['PRINCIPAL']<>principal | record['PROTECTION']<>'encrypt' then iterate
    /* Default Memory Fabric policy: keys originate in our Identity Directory.
     * An emergency file fallback is not implicitly a memory-read grant. */
    if record['SOURCE']<>'ldap' then iterate
    if record['STATE']<>'ACTIVE' & record['STATE']<>'RETIRING' then iterate
    from=record['NOTBEFORE']; until=record['NOTAFTER']
    if from==.nil | until==.nil then iterate
    if \datatype(from,'W') | \datatype(until,'W') then iterate
    if from>seconds | until<=seconds then iterate
    return principal
  end
  return .nil
denied:
  return .nil

::class MemoryXtp34ReadWire public
::method encode class
  use strict arg intent
  if \intent~isA(.MemoryXtpReadIntent) then raise syntax 88.900 array('Memory XTP read intent required')
  tab='09'x
  return 'MFXR1'||tab||c2x(intent~fabricId)||tab||c2x(intent~blockId)||tab||intent~generation||tab||intent~firstByte||tab||intent~endByte||tab||intent~pageBytes||tab||intent~requestId||tab||intent~expiresAtMs

::method decode class
  use strict arg wire
  if \wire~isA(.String) then return .nil
  if wire~length<20 | wire~length>2048 then return .nil
  if wire~pos('0a'x)>0 | wire~pos('0d'x)>0 then return .nil
  fields=.array~new; more=wire; tab='09'x
  do forever
    p=more~pos(tab)
    if p=0 then do
      fields~append(more)
      leave
    end
    fields~append(more~substr(1,p-1))
    if fields~items>8 then return .nil
    more=more~substr(p+1)
  end
  if fields~items<>9 | fields[1]<>'MFXR1' then return .nil
  do i=2 to 3
    hex=fields[i]
    if hex='' | hex~length>256 | hex~length//2<>0 then return .nil
    if hex~verify('0123456789ABCDEFabcdef')<>0 then return .nil
  end
  do i=4 to 7
    if \self~decimalField(fields[i]) then return .nil
  end
  if fields[8]='' | fields[8]~length>128 then return .nil
  if fields[8]~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_')<>0 then return .nil
  if \self~decimalField(fields[9]) then return .nil
  /* Every numeric field is already bounded before it reaches ooRexx's
   * 20-digit numeric context in MemoryXtpReadIntent. */
  signal on syntax name invalid
  return .MemoryXtpReadIntent~new(x2c(fields[2]),x2c(fields[3]),fields[4],fields[5],fields[6],fields[7],fields[8],fields[9])
invalid:
  return .nil

::method decimalField class private
  use strict arg field
  return field<>'' & field~length<=18 & field~verify('0123456789')=0

::class MemoryXtp34ReadBridge public
::method init
  expose gate service maxWire
  use strict arg readIngress, serviceName, maxWireBytes=2048
  if readIngress==.nil | \readIngress~hasMethod('ADMIT') then raise syntax 88.900 array('read ingress required')
  if datatype(maxWireBytes,'W')=0 | maxWireBytes<128 | maxWireBytes>2048 then raise syntax 88.900 array('read frame limit invalid')
  gate=readIngress; service=serviceName~string~strip; maxWire=maxWireBytes
  if service='' then raise syntax 88.900 array('read service required')

::method admitReceived
  expose gate service maxWire
  use strict arg acceptedSocket, trustedNowMs
  signal on syntax name refused
  signal on error name refused
  signal on failure name refused
  if acceptedSocket==.nil then return .nil
  if \acceptedSocket~isA(.XtpNamedAcceptedSocket) then return .nil
  /* The local XTP listener's authenticated service is authoritative. */
  if acceptedSocket~serviceName<>service then return .nil
  if acceptedSocket~protection<>'encrypt' then return .nil
  wire=acceptedSocket~recv(maxWire+1)
  if wire==.nil then return .nil
  if \wire~isA(.String) | wire~length>maxWire then return .nil
  /* A truncated or oversized wire request must never be partly admitted. */
  if acceptedSocket~recv(1)<>.nil then return .nil
  intent=.MemoryXtp34ReadWire~decode(wire)
  if intent==.nil then return .nil
  return gate~admit(intent,service,acceptedSocket,trustedNowMs)
refused:
  return .nil

::requires 'MemoryXtpReadIngress.cls'
::requires 'XtpSocketProvider.cls'
