#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
API_ROLLUP=${BRAND_API_ROLLUP:-}
python3 - "$ROOT" "$API_ROLLUP" <<'PY'
import hashlib, io, json, pathlib, sys, zipfile
root=pathlib.Path(sys.argv[1]); rollup=sys.argv[2]
pack=root/'packs'/'brand-interaction-stack'
sp=json.load(open(pack/'00-sphere.json'))
assert sp['id']=='brand-interaction-stack'
assert sp['version']=='0.5'
required_start={'ops.brand.start','arch.brand.authority-map','arch.brand.preflattening','arch.brand.structured-response','ops.brand.producer-admission','arch.brand.effect-evidence','arch.brand.journey-population','arch.brand.governance','ops.brand.intervention-jp03-repair','ops.brand.current-source-state','arch.brand.narrative-directive','ops.brand.current-compatibility','ref.brand.qualification'}
assert required_start <= set(sp['start_here'])
arts={p.stem:json.load(open(p)) for p in (pack/'articles').glob('*.json')}
required={
'ops.brand.start','arch.brand.authority-map','arch.brand.preflattening','arch.brand.structured-response','arch.brand.interaction-event','arch.brand.effect-evidence','arch.brand.journey','arch.brand.journey-population','arch.brand.intervention','arch.brand.effectiveness','arch.brand.governance','arch.brand.institutional-policy-seam','arch.brand.privacy-lineage','arch.brand.causal-boundaries','ops.brand.producer-admission','ops.brand.intervention-jp03-repair','ops.brand.current-source-state','arch.brand.narrative-directive','ops.brand.current-compatibility','ops.brand.requalification','ref.brand.protocols','ref.brand.source-map','ref.brand.qualification'}
assert required <= set(arts)
assert all(a.get('authority')=='project-authoritative' for a in arts.values())
assert all(a.get('provenance') for a in arts.values())
start=arts['ops.brand.start']
assert start['rollup']['sha256']=='190c3e9f7b484cfccc3e0fa4fe7fe07e6f0d15838ae2024b028ccaffd9652830'
assert start['current_baselines']['brand_journey_population']['version']=='0.3'
assert start['current_baselines']['brand_intervention_governance']['version']=='0.2'
assert start['current_baselines']['institutional_policy']['version']=='0.8'
state=arts['ops.brand.current-source-state']
assert state['manual_publication']['status']=='NOT_AUTOBUILD_QUALIFIED'
assert state['manual_publication']['tests_run'] is False
assert state['producer_v02_dev1']['test_request']=='REQ-00001495'
assert state['producer_v02_dev1']['payload_schema']=='structured.utterance.production-result/0.1'
assert state['brand_narrative_directive']['dispatch']=='NO_DISPATCH'
assert state['brand_narrative_directive']['publication_authority']=='NONE'
protos=arts['ref.brand.protocols']['apis']
assert protos['structured_utterance']=='structured.utterance/0.3'
assert protos['interaction_event']=='interaction.event/0.3'
assert protos['brand_interaction_effect']=='brand.interaction.effect/0.6'
assert protos['brand_journey_population']=='brand.journey.population/0.3'
assert protos['brand_intervention']=='brand.intervention/0.2'
assert protos['brand_intervention_effectiveness']=='brand.intervention.effectiveness/0.2'
assert protos['brand_intervention_governance']=='brand.intervention.governance/0.2'
assert protos['institutional_policy']=='institutional.policy/0.8'
less=json.load(open(pack/'corpora'/'brand.lessons.json'))
gloss=json.load(open(pack/'corpora'/'brand.glossary.json'))
assert len(less['records'])>=20
assert len(gloss['records'])>=20
assert any(r.get('topic')=='current-gap' for r in less['records'])
assert any(r.get('topic')=='submission-not-acceptance' for r in less['records'])
assert any(r.get('topic')=='cognitive-admission' for r in less['records'])
assert any(r.get('term')=='current compatibility gap' for r in gloss['records'])

expected={k:v['sha256'] for k,v in start['current_baselines'].items() if 'artifact' in v and 'sha256' in v}
art_to_hash={v['artifact']:v['sha256'] for v in start['current_baselines'].values() if isinstance(v,dict) and 'artifact' in v and 'sha256' in v}
manifest=root/'qualification'/'MANIFEST.sha256'
for line in manifest.read_text().splitlines():
    if not line.strip(): continue
    digest, rel=line.split(None,1)
    rel=rel.strip()
    assert rel!='qualification/MANIFEST.sha256'
    target=root/rel
    assert target.is_file(), rel
    assert hashlib.sha256(target.read_bytes()).hexdigest()==digest, rel
if rollup:
    rp=pathlib.Path(rollup)
    got=hashlib.sha256(rp.read_bytes()).hexdigest()
    assert got==start['rollup']['sha256'],(got,start['rollup']['sha256'])
    outer=zipfile.ZipFile(rp)
    nested={}
    for artifact,sha in art_to_hash.items():
        member='current/'+artifact
        assert member in outer.namelist(), member
        data=outer.read(member)
        assert hashlib.sha256(data).hexdigest()==sha, artifact
        nested[artifact]=zipfile.ZipFile(io.BytesIO(data))
    for a in arts.values():
        for ev in a.get('provenance',[]):
            z=nested.get(ev['artifact'])
            if z is not None:
                assert ev['member'] in z.namelist(), (a['id'],ev['artifact'],ev['member'])
print('PASS brand-interaction-stack sphere structure/provenance contract')
PY
