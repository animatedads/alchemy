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
assert sp['version']=='0.1'
required_start={'ops.brand.start','arch.brand.authority-map','arch.brand.preflattening','arch.brand.effect-evidence','arch.brand.journey-population','arch.brand.governance','ops.brand.current-compatibility','ref.brand.qualification'}
assert required_start <= set(sp['start_here'])
arts={p.stem:json.load(open(p)) for p in (pack/'articles').glob('*.json')}
required={
'ops.brand.start','arch.brand.authority-map','arch.brand.preflattening','arch.brand.interaction-event','arch.brand.effect-evidence','arch.brand.journey','arch.brand.journey-population','arch.brand.intervention','arch.brand.effectiveness','arch.brand.governance','arch.brand.institutional-policy-seam','arch.brand.privacy-lineage','arch.brand.causal-boundaries','ops.brand.current-compatibility','ops.brand.requalification','ref.brand.protocols','ref.brand.source-map','ref.brand.qualification'}
assert required <= set(arts)
assert all(a.get('authority')=='project-authoritative' for a in arts.values())
assert all(a.get('provenance') for a in arts.values())
start=arts['ops.brand.start']
assert start['rollup']['sha256']=='190c3e9f7b484cfccc3e0fa4fe7fe07e6f0d15838ae2024b028ccaffd9652830'
assert start['current_baselines']['brand_journey_population']['version']=='0.3'
assert start['current_baselines']['brand_intervention_governance']['version']=='0.2'
assert start['current_baselines']['institutional_policy']['version']=='0.8'
gap=arts['ops.brand.current-compatibility']
assert 'configureProvenance' in gap['qualification']['gap']
assert 'BrandJourneyPopulation' in gap['qualification']['gap']
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
assert any(r.get('term')=='current compatibility gap' for r in gloss['records'])

expected={k:v['sha256'] for k,v in start['current_baselines'].items() if 'artifact' in v and 'sha256' in v}
art_to_hash={v['artifact']:v['sha256'] for v in start['current_baselines'].values() if isinstance(v,dict) and 'artifact' in v and 'sha256' in v}
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
