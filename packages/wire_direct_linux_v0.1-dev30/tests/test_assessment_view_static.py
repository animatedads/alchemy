from pathlib import Path
p=Path('rexx/WireAssessmentView.cls').read_text()
contract=Path('qualification/contracts/MLAssessment_dev11.contract.txt').read_text()
assert '713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79' in contract
assert 'Verified public class: MLAssessment' in contract
for a in ['kind','value','modelId','modelPoint','branch']:
    assert a in contract
for token in ['assessment~kind','assessment~modelId','assessment~modelPoint','assessment~branch','a~value']:
    assert token in p
for forbidden in ['train(', '~train', 'fit(', '~fit', 'uidFetch', 'Gtk', 'reorder', 'sort']:
    assert forbidden not in p
assert 'return .nil' in p
print('PASS pinned ML dev11 assessment contract: sparse historical lookup + projection-only authority')
