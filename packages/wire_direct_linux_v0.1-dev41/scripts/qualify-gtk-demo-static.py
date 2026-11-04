from pathlib import Path
s=Path('src/wire_gtk4_renderer.c').read_text()
d=Path('examples/wire_demo.c').read_text()
assert 'gtk_application_window_new(s->app)' in s
assert 'g_application_register(G_APPLICATION(s->app)' in s
assert 'g_application_run(G_APPLICATION(s->app),0,NULL)' in s
assert 'gtk_window_new()' not in s
assert 'DemoRows rows={200000' in d
assert 'WIRE_VIRTUAL_LIST' in d and 'show_list_range(r,3,0,100)' in d
assert 'SelectionChanged' in s and 'WIRE_STABLE_ID_KEY' in s
print('PASS GTK demo lifecycle contract: registered GtkApplication + application window + bounded 200000-row virtual-list host')
