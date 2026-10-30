#!/usr/bin/env python3
import sys
from pathlib import Path
if len(sys.argv)!=2: raise SystemExit('usage: check_storage_target.py STORAGE_PACKAGE_ROOT')
root=Path(sys.argv[1]); src=root/'src'/'StorageFabric.cls'
if not src.is_file(): raise SystemExit('FAIL StorageFabric.cls missing')
s=src.read_text(errors='strict')
checks={
 'large-object precision':'::options digits 30' in s,
 'canonical unsigned writer':'::method unsignedText class' in s,
 'canonical unsigned parser':'::method parseUnsigned class' in s,
 'replica count API':'::attribute requiredReplicas get' in s,
 'vendor diversity API':'::attribute distinctVendors get' in s,
 'site diversity API':'::attribute distinctSites get' in s,
 'failure-domain API':'::attribute distinctFailureDomains get' in s,
}
bad=[k for k,v in checks.items() if not v]
if bad: raise SystemExit('FAIL incompatible Storage target: '+', '.join(bad))
print('PASS Storage target compatibility: precision + replica-policy API')
