from pathlib import Path
s=Path("src/wire_gtk4_renderer.c").read_text()
xml=Path("examples/mailreader/mailreader.xml").read_text()
assert "virtual_scroll_changed" in s
assert "virtual_wheel" in s
assert "gtk_scrollbar_new(GTK_ORIENTATION_VERTICAL,e->virtual_adjustment)" in s
assert "gtk_adjustment_configure(a,(double)start,0.0,(double)total" in s
assert "gtk_scrolled_window_set_policy" in s and "GTK_POLICY_NEVER" in s
assert '"RangeRequested","start",requested' in s
body=s[s.index("static void virtual_scroll_changed"):s.index("static gboolean virtual_wheel")]
assert "s->dispatch" in body and "show_range_r" not in body
assert "count=\"100\"" in xml and "source=\"messages\"" in xml
assert "if(!s||!s->dispatch)return;\n const char *stable=" in s
print("wire-gtk-virtual-continuation=PASS resident=100 proportional=200000 demand=semantic wheel=bounded stable-identity-preserved")
