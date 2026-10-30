from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'rexx/WireRendererEventPort.cls').read_text()
assert '.WireApplicationEvent~new(source, trigger, context' in s
assert 'model~scopedUI(scopes[source])' in s
assert 'controller~dispatch(event)' in s
for forbidden in ('Gtk','Gdk','Android','HWND','DOM','IMAP','uidFetch'):
    assert forbidden not in s, forbidden
print('PASS renderer event ingress: semantic event + scoped UI, no native toolkit authority')
