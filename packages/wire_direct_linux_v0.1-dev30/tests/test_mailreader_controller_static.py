from pathlib import Path
s=(Path(__file__).parents[1]/'rexx'/'WireMailReaderController.cls').read_text()
assert '.WireImapMessageResolver~new(mailbox)' in s
assert '.WireElementTarget~new(ui, "message")' in s
assert '.WireSelectionProjection~new' in s
assert 'mailbox~fetchBody' not in s and 'ui~byId' not in s and 'Gtk' not in s
print('PASS compatibility controller is composition-only')
