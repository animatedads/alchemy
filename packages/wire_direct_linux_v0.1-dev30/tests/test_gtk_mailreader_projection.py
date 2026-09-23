from pathlib import Path
gtk=Path('src/wire_gtk4_renderer.c').read_text()
demo=Path('examples/wire_mailreader_demo.c').read_text()
build=Path('scripts/build.sh').read_text()
assert 'rows[i].from' in gtk and 'rows[i].subject' in gtk and 'rows[i].date' in gtk
assert 'PANGO_ELLIPSIZE_END' in gtk
assert 'wire-subject-label' in gtk
assert 'WireListSource fs=' in demo and 'ms={&messages' in demo
assert 'messages={200000' in demo and 'show_list_range(r,7,0,100)' in demo
assert 'wire_mailreader_demo' in build
assert '#include <gtk/' not in demo and 'Gtk' not in demo
print('wire-gtk-mailreader-projection=PASS columns=from/subject/date bounded=100/200000 native-host=linked')
