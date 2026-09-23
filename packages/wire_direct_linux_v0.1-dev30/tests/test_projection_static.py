from pathlib import Path
root=Path(__file__).parents[1]
p=(root/'rexx/WireSelectionProjection.cls').read_text()
r=(root/'rexx/WireImapMessageResolver.cls').read_text()
t=(root/'rexx/WireElementTarget.cls').read_text()
c=(root/'rexx/WireMailReaderController.cls').read_text()
assert 'context["identity"]' in p and 'valueForIdentity(identity)' in p and 'setProperty(property, value)' in p
assert 'WIRE_STALE_IDENTITY' in r and 'mailbox~fetchBody' in r
assert 'ui~byId(elementId)' in t
assert 'fetchBody' not in c and 'byId' not in c and 'Gtk' not in c
print('PASS selection projection split: generic projection + IMAP resolver + semantic target')
