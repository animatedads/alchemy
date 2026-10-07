from pathlib import Path
import json, re
root=Path(__file__).resolve().parents[1]
cls=(root/'src'/'SemanticSourceCodeExaminer.cls').read_text(encoding='utf-8')
ui=json.loads((root/'wire'/'CODE_EXAMINER_UI_DESIGN.json').read_text(encoding='utf-8'))
required_actions={
 'CODE.CATALOG','CODE.SEARCH','CODE.OPEN','CODE.FINDING.CREATE','CODE.FINDING.RESOLVE',
 'CODE.PACKAGE.REQUEST','CODE.TEST.REQUEST','WORK.ACCEPT','WORK.REFUSE','CODE.REFRESH',
 'CODE.COMPARE','METHOD.REQUIREMENT.CREATE','METHOD.NOTE.CREATE','RESOURCE.UPLOAD',
 'MODULE.REQUIREMENT.CREATE','DEPLOYMENT.PACKAGE.REQUEST','BRANCH.CLASSIFY','BRANCH.PROTECT',
 'BRANCH.PACKAGE.REQUEST','BRANCH.CONFLICT.RESOLVE','CODE.GOTO_DEFINITION','CODE.FIND_USES',
 'CODE.CALLERS','CODE.CALLEES','CODE.REFERENCE.EXPLAIN','CODE.CLASS.SURFACE','CODE.CLASS.OVERRIDES'
}
values=set(ui['semanticActions'].values())
missing=required_actions-values
assert not missing, f'UI missing agreed semantic actions: {sorted(missing)}'
for action in required_actions:
    assert action in cls, f'examiner server missing action {action}'
required_panels={'METHOD_META','RESOURCES','MODULES','BRANCHES','SEMANTIC_GRAPH','RUNTIME_SURFACE','VERSION_COMPARE'}
contains={x for r in ui['root']['regions'] for x in r.get('contains',[])}
missing=required_panels-contains
assert not missing, f'UI missing agreed panels/features: {sorted(missing)}'
for key in ['revision_history','requirements','notes','resources','branches','deployments','references','runtime_surfaces','test_evidence','work_entries','exports','dependencies']:
    assert f'"{key}"' in cls, f'CODE.OPEN context contract missing {key}'
print('EXAMINER FEATURE CONTRACT TEST: PASS')
