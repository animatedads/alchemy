from pathlib import Path
root=Path(__file__).resolve().parents[1]
imp=(root/'src/SemanticSourceBulkImporter.cls').read_text()
adapter=(root/'src/SemanticSourceOorexxStructuralAdapter.cls').read_text()
assert 'semantic_source_authority"] = "STRUCTURAL_GRAPH"' in imp
assert 'semantic_objects' in imp and 'projection_members' in imp and 'relations' in imp
assert 'lossless_reconstruction_verified' in imp
assert 'oorexx-structural-v4' in imp
for kind in ['EXECUTABLE_SECTION','CLASS','METHOD','ATTRIBUTE','CONSTANT','ROUTINE','REQUIRES','RESOURCE','OPTIONS']:
    assert kind in adapter, kind
assert 'reconstruct' in adapter
print('STRUCTURAL IMPORT CONTRACT TEST: PASS')
