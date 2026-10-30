from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'rexx/WireBuilderSession.cls').read_text()
d=(p/'rexx/WireBehaviourDraft.cls').read_text()
assert '::method newBehaviourDraft' in s
assert '.WireBehaviourDraft~new(selectedSource, selectedTrigger, behaviour, method)' in s
assert '::method replaceSource' in d and '::attribute source get' in d
assert '::method' in d and 'use strict arg event' in d
for forbidden in ('Gtk', 'Gdk', 'HWND', 'ooDialog', 'Imap', 'SocketProvider', 'SourceEditor~new'):
    assert forbidden not in d+s, forbidden
print('wire-behaviour-draft=PASS editor-neutral ordinary-rexx method handoff')
