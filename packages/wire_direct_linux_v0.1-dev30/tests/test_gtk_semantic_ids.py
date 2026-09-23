from pathlib import Path
root=Path(__file__).resolve().parents[1]
gtk=(root/'src/wire_gtk4_renderer.c').read_text()
demo=(root/'examples/wire_mailreader_demo.c').read_text()
assert 'char *semantic_id' in gtk
assert 'p->key,"id"' in gtk
assert 'e->semantic_id?e->semantic_id:id' in gtk
assert 'prop(r,7,"id","messages")' in demo
assert 'Rows folders={12' in demo and 'messages={200000' in demo
assert 'show_list_range(r,7,0,100)' in demo
assert '#include <gtk/' not in demo and 'Gtk' not in demo
print('wire-gtk-semantic-id=PASS mailreader=folders/messages/message bounded=100/200000')
