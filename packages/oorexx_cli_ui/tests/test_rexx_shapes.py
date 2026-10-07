from pathlib import Path
r=Path(__file__).resolve().parents[1]
d=(r/'rexx/CliUiDocument.cls').read_text(); s=(r/'rexx/CliUiSyntax.cls').read_text(); c=(r/'rexx/CliUiCompletion.cls').read_text(); m=(r/'examples/mailreader/MailReader.rex').read_text()
for x in ['replaceSelection','backspace','delete','selection']: assert x in d
for x in ['CliUiSimpleSyntax','addWord','keyword']: assert x in s
for x in ['CliUiCompletionService','CliUiWordCompletion']: assert x in c
for x in ['messageWindow','fetchBody','sendSigned','signingIdentity']: assert x in m
print('PASS Rexx shape gates')

assert 'CliUiEditorProjection' in (r/'rexx/CliUiEditorProjection.cls').read_text()
assert 'prefixLength' in (r/'rexx/CliUiCompletion.cls').read_text()
assert 'document~backspace' in (r/'rexx/CliUiEditor.cls').read_text()

assert 'CliUiEditorController' in (r/'rexx/CliUiEditorController.cls').read_text()
