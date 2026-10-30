from pathlib import Path
root=Path(__file__).resolve().parents[1]
host=(root/'examples/wire_mailreader_demo.c').read_text()
loader=(root/'src/wire_ui_loader.c').read_text()
hdr=(root/'include/wire_ui_loader.h').read_text()
assert 'App app={r,0,0,0}' in host
assert 'message_window=count' in host
assert 'show_list_range(a->renderer,a->messages,start,a->message_window)' in host
assert 'WireUIVirtualListLoaded' in hdr
assert 'virtual_list_loaded' in loader
assert 'c->virtual_list_loaded' in loader
assert 'message_window=100' not in host
print('wire-declarative-virtual-policy=PASS resident-count-owned-by-ui-definition')
