#!/usr/bin/env python3
"""Dependency-free package/sphere semantic checks; NOT a runtime XTP test."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SPHERE=ROOT/'sphere'
def check(condition,why):
    if not condition:raise AssertionError(why)
manifest=json.loads((ROOT/'integration.json').read_text())
check(manifest['schema']=='alchemy.autobuild.integration/0.3','Autobuild schema')
check(manifest['package']['version']=='0.1-candidate2','candidate version')
check(manifest['publish']['tree']['path']=='packages/oorexx_memory_fabric_xtp_candidate2','source destination')
pack=SPHERE/'packs/memory-fabric'
meta=json.loads((pack/'00-sphere.json').read_text())
policy=json.loads((pack/'01-access-policy.json').read_text())
profile=json.loads((SPHERE/'profiles/memory-fabric.json').read_text())
check(meta['kind']=='sphere' and meta['id']=='memory-fabric','sphere identity')
check(meta['access_policy']==policy['id'],'sphere policy ref')
check('packs/memory-fabric' in profile['packs'],'sphere activation pack')
asserted=set()
for f in sorted((pack/'articles').glob('*.json')):
    obj=json.loads(f.read_text()); asserted.add(obj['id'])
    check(obj['kind']=='article' and obj['sphere']=='memory-fabric','article namespace')
    check(obj['id']==f.stem and len(obj['invariants'])>2,'article identity/content')
    for p in obj['provenance']:
        check(len(p['sha256'])==64 and p['member'] and p['claim'],'provenance evidence')
check(set(meta['start_here'])==asserted,'sphere references')
glossary=json.loads((pack/'corpora/memory-fabric.glossary.json').read_text())
check(glossary['sphere']=='memory-fabric' and len(glossary['records'])>=8,'glossary')
src=(ROOT/'src/MemoryXtpAdmission.cls').read_text()
planner=(ROOT/'src/MemoryXtpTransferPlanning.cls').read_text()
for token in ['registry~resolveBlock','replicaVerifier~verifies','capacityRate(rate)','governor~acquire','governor~release', 'governor~reconcile','namedManager~descriptor','authority~current','socket~hasMethod']:
    check(token in src,'missing adapter contract: '+token)
check('capacitySlots=policy~aggregateCapPercent%policy~perContextCapPercent' in planner,'aggregate overcommit regression')
check('XtpNamedServiceAddress~multicast' in (ROOT/'docs/XTP_ADMISSION_DEV25.md').read_text(),'multicast gap explicit')
paths={x['path'] for x in manifest['publish'].get('files',[])}
for file in SPHERE.rglob('*'):
    if file.is_file():check('spheres/memory_fabric_gopher_sphere_v0.1/'+file.relative_to(SPHERE).as_posix() in paths,'unpublished sphere file '+str(file))
print(f'PASS static package + {len(asserted)} Gopher articles, glossary, provenance, publish map (not live qualification)')
