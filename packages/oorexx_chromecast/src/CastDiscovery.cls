/* CastDiscovery.cls - mDNS/DNS-SD codec and Chromecast service projection. */

::class MdnsRecordType public
::constant A 1
::constant PTR 12
::constant TXT 16
::constant AAAA 28
::constant SRV 33

::class MdnsNameCodec public
::method encode class
  use strict arg nameArg
  name=nameArg~string~strip
  if right(name,1)="." then name=left(name,length(name)-1)
  out=""
  do while name<>""
    dot=pos(".",name)
    if dot=0 then do; label=name; name=""; end
    else do; label=left(name,dot-1); name=substr(name,dot+1); end
    if length(label)>63 then raise syntax 88.900 array("DNS label too long")
    out=out||d2c(length(label))||label
  end
  return out||"00"x

::method decode class
  use strict arg packet, offset
  p=offset; out=""; nextOffset=0; jumps=0
  do forever
    if p>length(packet) then raise syntax 88.900 array("truncated DNS name")
    len=c2d(substr(packet,p,1))
    if len>=192 then do
      if p+1>length(packet) then raise syntax 88.900 array("truncated DNS pointer")
      ptr=(len//64)*256+c2d(substr(packet,p+1,1))+1
      if nextOffset=0 then nextOffset=p+2
      p=ptr; jumps+=1
      if jumps>64 then raise syntax 88.900 array("DNS compression loop")
      iterate
    end
    p+=1
    if len=0 then leave
    if p+len-1>length(packet) then raise syntax 88.900 array("truncated DNS label")
    label=substr(packet,p,len); p+=len
    if out<>"" then out=out||"."
    out=out||label
  end
  if nextOffset=0 then nextOffset=p
  return .array~of(out,nextOffset)

::class MdnsRecord public
::method init
  expose name type rrclass ttl data raw
  use strict arg name, type, rrclass, ttl, data, raw=""
  name=name~string
  type=type+0; rrclass=rrclass+0; ttl=ttl+0; data=data; raw=raw
::attribute name get
::attribute type get
::attribute rrclass get
::attribute ttl get
::attribute data get
::attribute raw get

::class MdnsMessage public
::method init
  expose id flags questions answers authorities additionals
  use strict arg id, flags, questions, answers, authorities, additionals
  id=id; flags=flags; questions=questions; answers=answers; authorities=authorities; additionals=additionals
::attribute id get
::attribute flags get
::attribute questions get
::attribute answers get
::attribute authorities get
::attribute additionals get
::method allRecords
  expose answers authorities additionals
  a=.array~new
  do r over answers; a~append(r); end
  do r over authorities; a~append(r); end
  do r over additionals; a~append(r); end
  return a

::class MdnsCodec public
::method u16 class
  use strict arg packet, p
  if p+1>length(packet) then raise syntax 88.900 array("truncated DNS u16")
  return c2d(substr(packet,p,1))*256+c2d(substr(packet,p+1,1))
::method u32 class
  use strict arg packet, p
  if p+3>length(packet) then raise syntax 88.900 array("truncated DNS u32")
  return c2d(substr(packet,p,1))*16777216+c2d(substr(packet,p+1,1))*65536+c2d(substr(packet,p+2,1))*256+c2d(substr(packet,p+3,1))
::method put16 class
  use strict arg n
  return d2c((n%256)//256)||d2c(n//256)

::method castQuery class
  name=.MdnsNameCodec~encode("_googlecast._tcp.local")
  /* ID=0, flags=0, QDCOUNT=1; PTR/IN question */
  return "000000000001000000000000"x||name||"000c0001"x

::method decode class
  use strict arg packet
  if length(packet)<12 then raise syntax 88.900 array("short DNS packet")
  id=self~u16(packet,1); flags=self~u16(packet,3)
  qd=self~u16(packet,5); an=self~u16(packet,7); ns=self~u16(packet,9); ar=self~u16(packet,11)
  p=13; questions=.array~new
  do qd
    n=.MdnsNameCodec~decode(packet,p); p=n[2]
    qtype=self~u16(packet,p); qclass=self~u16(packet,p+2); p+=4
    q=.directory~new; q["name"]=n[1]; q["type"]=qtype; q["class"]=qclass; questions~append(q)
  end
  answers=.array~new; authorities=.array~new; additionals=.array~new
  x=self~decodeRecords(packet,p,an); answers=x[1]; p=x[2]
  x=self~decodeRecords(packet,p,ns); authorities=x[1]; p=x[2]
  x=self~decodeRecords(packet,p,ar); additionals=x[1]
  return .MdnsMessage~new(id,flags,questions,answers,authorities,additionals)

::method decodeRecords class
  use strict arg packet, pArg, count
  p=pArg; records=.array~new
  do count
    n=.MdnsNameCodec~decode(packet,p); name=n[1]; p=n[2]
    type=self~u16(packet,p); rrclass=self~u16(packet,p+2); ttl=self~u32(packet,p+4); rdlen=self~u16(packet,p+8); p+=10
    if p+rdlen-1>length(packet) then raise syntax 88.900 array("truncated DNS RDATA")
    raw=substr(packet,p,rdlen); data=raw
    select
      when type=.MdnsRecordType~PTR then data=.MdnsNameCodec~decode(packet,p)[1]
      when type=.MdnsRecordType~SRV then do
        if rdlen<6 then raise syntax 88.900 array("short SRV RDATA")
        d=.directory~new
        d["priority"]=self~u16(packet,p); d["weight"]=self~u16(packet,p+2); d["port"]=self~u16(packet,p+4)
        d["target"]=.MdnsNameCodec~decode(packet,p+6)[1]
        data=d
      end
      when type=.MdnsRecordType~TXT then data=self~decodeTxt(raw)
      when type=.MdnsRecordType~A then do
        if rdlen=4 then data=c2d(substr(raw,1,1))||"."||c2d(substr(raw,2,1))||"."||c2d(substr(raw,3,1))||"."||c2d(substr(raw,4,1))
      end
      when type=.MdnsRecordType~AAAA then data=self~formatIpv6(raw)
      otherwise nop
    end
    records~append(.MdnsRecord~new(name,type,rrclass,ttl,data,raw))
    p+=rdlen
  end
  return .array~of(records,p)

::method decodeTxt class
  use strict arg raw
  d=.directory~new; p=1
  do while p<=length(raw)
    n=c2d(substr(raw,p,1)); p+=1
    if p+n-1>length(raw) then raise syntax 88.900 array("truncated DNS TXT")
    s=substr(raw,p,n); p+=n
    eq=pos("=",s)
    if eq=0 then d[s]=""
    else d[left(s,eq-1)]=substr(s,eq+1)
  end
  return d

::method formatIpv6 class
  use strict arg raw
  if length(raw)<>16 then return c2x(raw)
  out=""
  do i=1 to 16 by 2
    if out<>"" then out=out||":"
    out=out||strip(c2x(substr(raw,i,2)),"L","0")
    if right(out,1)=":" then out=out||"0"
  end
  return lower(out)

::class CastDiscoveredService public
::method init
  expose instance serviceType host port addresses txt records
  use strict arg instance, host, port, addresses, txt=.nil, records=.nil, serviceType="_googlecast._tcp.local"
  instance=instance~string; host=host~string; port=port+0; addresses=addresses
  if txt=.nil then txt=.directory~new
  if records=.nil then records=.array~new
  txt=txt; records=records; serviceType=serviceType
::attribute instance get
::attribute serviceType get
::attribute host get
::attribute port get
::attribute addresses get
::attribute txt get
::attribute records get
::method friendlyName
  expose txt instance
  if txt~hasIndex("fn") then return txt["fn"]
  return instance
::method model
  expose txt
  if txt~hasIndex("md") then return txt["md"]
  return ""
::method deviceId
  expose txt
  if txt~hasIndex("id") then return txt["id"]
  return ""
::method primaryAddress
  expose addresses
  if addresses~items=0 then return ""
  return addresses[1]

::class CastDiscovery public
::constant SERVICE_TYPE "_googlecast._tcp.local"
::constant MDNS_IPV4 "224.0.0.251"
::constant MDNS_PORT 5353
::method queryPacket class
  return .MdnsCodec~castQuery
::method servicesFromPacket class
  use strict arg packet
  return self~servicesFromMessage(.MdnsCodec~decode(packet))
::method servicesFromMessage class
  use strict arg message
  records=message~allRecords
  ptr=.set~new; srv=.directory~new; txt=.directory~new; address=.directory~new
  do r over records
    select
      when r~type=.MdnsRecordType~PTR then do
        if lower(r~name)=lower(self~SERVICE_TYPE) then ptr~put(r~data)
      end
      when r~type=.MdnsRecordType~SRV then srv[r~name]=r~data
      when r~type=.MdnsRecordType~TXT then txt[r~name]=r~data
      when r~type=.MdnsRecordType~A | r~type=.MdnsRecordType~AAAA then do
        host=r~name
        if \address~hasIndex(host) then address[host]=.array~new
        address[host]~append(r~data)
      end
    end
  end
  /* Some responders omit PTR in follow-up packets; retain SRV names with the Cast suffix. */
  do name over srv~allIndexes
    if pos("."||lower(self~SERVICE_TYPE),lower(name))>0 then ptr~put(name)
  end
  out=.array~new
  do instance over ptr
    if \srv~hasIndex(instance) then iterate
    s=srv[instance]; host=s["target"]
    addrs=.array~new
    if address~hasIndex(host) then addrs=address[host]
    t=.directory~new
    if txt~hasIndex(instance) then t=txt[instance]
    out~append(.CastDiscoveredService~new(instance,host,s["port"],addrs,t,records))
  end
  return out
