from pathlib import Path
p=Path('qualification/contracts/JAVASCRIPT_ALCHEMY_DEV23.contract.txt').read_text()
assert '93f1691348382ba2c1a24046e0796ed5371b076de9dedbfef872ec57afadab6f' in p
assert 'QuickJS-NG 0.17.0' in p
assert 'Wire does not own JavaScript dispatch or GTK authority' in p
w=Path('rexx/WireLanguageBlock.cls').read_text()
assert 'QuickJS' not in w and 'JavaScript' not in w
print('PASS JavaScript Alchemy dev23 pinned as implementation behind generic Rexx language-block boundary')
