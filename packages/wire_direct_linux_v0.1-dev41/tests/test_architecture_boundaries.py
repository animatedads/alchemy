from pathlib import Path
root=Path(__file__).parents[1]
areas={
 'renderer':[root/'src/wire_gtk4_renderer.c',root/'src/wire_test_renderer.c'],
 'imap':[root/'rexx/WireImapSource.cls',root/'rexx/WireImapMessageResolver.cls'],
 'projection':[root/'rexx/WireSelectionProjection.cls'],
 'target':[root/'rexx/WireElementTarget.cls'],
}
forbidden={
 'renderer':['ImapSession','WireImap','uidFetch','BODY.PEEK','timeout_add','sync_interval'],
 'imap':['Gtk','Gdk','Adw','GestureDrag','pointer_x','WireSelectionProjection'],
 'projection':['Gtk','Gdk','Adw','Imap','uidFetch','BODY.PEEK','timeout','GestureDrag','pointer_x','byId'],
 'target':['Gtk','Gdk','Adw','Imap','uidFetch','BODY.PEEK','timeout','GestureDrag','pointer_x'],
}
for area,files in areas.items():
 text='\n'.join(p.read_text() for p in files)
 for token in forbidden[area]:
  assert token not in text, f'{area} illegally depends on {token}'
# Builder geometry must never appear in runtime/domain slices in this package.
for p in list((root/'rexx').glob('*.cls'))+[root/'src/wire_test_renderer.c']:
 t=p.read_text()
 assert 'drag-begin' not in t and 'drag-update' not in t and '_pointer_x' not in t, p
print('PASS architecture boundaries: renderer/source/projection/target authorities remain separated')
