from pathlib import Path
p=Path('rexx/WireVisibleAssessmentProjection.cls').read_text()
h=Path('include/wire_renderer.h').read_text()
t=Path('tests/test_core.c').read_text()
assert '#define WIRE_RENDERER_ABI 4u' in h
assert 'set_list_row_property' in h and 'WireListRowProperty' in h
assert 'assessmentForSubject' in p and 'setRowProperty' in p
for forbidden in ['uidFetch','Gtk','~train','~fit', '~sort','~reorder','show_list_range']:
    assert forbidden not in p
assert 'assert(b.range_calls==1)' in t
assert '999999' in t and 'WIRE_ESTATE' in t
print('PASS visible assessment projection: sparse in-place row update, no refetch/reorder/training authority')
