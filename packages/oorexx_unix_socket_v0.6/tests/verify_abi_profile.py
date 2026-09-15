#!/usr/bin/env python3
import json, sys
bridge, probe_path = sys.argv[1:3]
with open(bridge, encoding='utf-8') as f: doc=json.load(f)
profile='linux-x86_64-le-lp64'
prof=doc['abiProfiles'][profile]
with open(probe_path, encoding='utf-8') as f:
    probe={k:int(v) for line in f if '=' in line for k,v in [line.strip().split('=',1)]}
errors=[]
for name,spec in prof['constants'].items():
    if name not in probe: continue
    actual=probe[name]; expected=int(str(spec['value']),0)
    if actual!=expected: errors.append(f'constant {name}: bridge={expected} C={actual}')

type_maps={
 'iovec':('IOVEC_SIZE','IOVEC_ALIGNMENT',{'iov_base':'IOV_BASE_OFFSET','iov_len':'IOV_LEN_OFFSET'}),
 'msghdr':('MSGHDR_SIZE','MSGHDR_ALIGNMENT',{'msg_name':'MSG_NAME_OFFSET','msg_namelen':'MSG_NAMELEN_OFFSET','msg_iov':'MSG_IOV_OFFSET','msg_iovlen':'MSG_IOVLEN_OFFSET','msg_control':'MSG_CONTROL_OFFSET','msg_controllen':'MSG_CONTROLLEN_OFFSET','msg_flags':'MSG_FLAGS_OFFSET'}),
 'pollfd':('POLLFD_SIZE','POLLFD_ALIGNMENT',{'fd':'POLLFD_FD_OFFSET','events':'POLLFD_EVENTS_OFFSET','revents':'POLLFD_REVENTS_OFFSET'}),
 'cmsghdr':('CMSGHDR_SIZE','CMSGHDR_ALIGNMENT',{'cmsg_len':'CMSG_LEN_OFFSET','cmsg_level':'CMSG_LEVEL_OFFSET','cmsg_type':'CMSG_TYPE_OFFSET'}),
 'ucred':('UCRED_SIZE',None,{'pid':'UCRED_PID_OFFSET','uid':'UCRED_UID_OFFSET','gid':'UCRED_GID_OFFSET'}),
 'stat':('STAT_SIZE','STAT_ALIGNMENT',{'st_dev':'STAT_DEV_OFFSET','st_ino':'STAT_INO_OFFSET','st_mode':'STAT_MODE_OFFSET','st_uid':'STAT_UID_OFFSET','st_gid':'STAT_GID_OFFSET'}),
}
for t,(sizekey,alignkey,fields) in type_maps.items():
    spec=prof['types'][t]
    if spec['size']!=probe[sizekey]: errors.append(f'type {t} size: bridge={spec["size"]} C={probe[sizekey]}')
    if alignkey and spec['alignment']!=probe[alignkey]: errors.append(f'type {t} align: bridge={spec["alignment"]} C={probe[alignkey]}')
    offsets={f['name']:f['offset'] for f in spec['fields']}
    for fname,key in fields.items():
        if offsets[fname]!=probe[key]: errors.append(f'type {t}.{fname}: bridge={offsets[fname]} C={probe[key]}')
if errors:
    print('FAIL executable ABI profile differs from C headers')
    for e in errors: print('  '+e)
    sys.exit(1)
print(f'PASS bridge ABI metadata matches C headers profile={profile} constants={sum(1 for k in prof["constants"] if k in probe)} types={len(type_maps)}')
