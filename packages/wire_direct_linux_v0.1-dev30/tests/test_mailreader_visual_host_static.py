from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'examples/wire_mailreader_demo.c').read_text()
g=(root/'src/wire_gtk4_renderer.c').read_text()
for forbidden in ('#include <gtk','GtkWidget','GtkApplication','gtk_'):
    assert forbidden not in s, forbidden
for required in ('"Folders"','"Messages — 100-row window / 200,000 backing messages"','"Message"','"width","1200"','"height","760"'):
    assert required in s, required
assert 'SelectionChanged' in s and 'Stable Wire identity:' in s
assert 'set_property(a->renderer,14' in s
assert '"width"' in g and '"height"' in g and 'gtk_window_set_default_size' in g
print('wire-mailreader-visual-host=PASS panes=folders/messages/message bounded=100/200000 semantic-roundtrip=selection->document')
