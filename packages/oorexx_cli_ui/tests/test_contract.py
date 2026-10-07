from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/'include/oorexx_cli_ui.h').read_text()
a=(r/'docs/ARCHITECTURE.md').read_text()
for s in ['CLIUI_EVENT_RESIZE','CLIUI_STYLE_SELECTION','CliUiSelection','cliui_ansi_create','cliui_curses_create']: assert s in h
for s in ['Terminal-global mouse selection','NewShell CLI is a client','editor: ooRexx/JSON/Python','SMTP Secure Stack','LDAP/Identity']: assert s in a
ansi=(r/'src/cliui_ansi.c').read_text()
for forbidden in ['?1000h','?1002h','?1003h','?1049h','?2004h']: assert forbidden not in ansi
print('PASS CLI UI contract')

assert '#define OOREXX_CLI_UI_ABI 2u' in h
assert 'CliUiIo' in h and 'cliui_ansi_create_with_io' in h
ansi=(r/'src'/'cliui_ansi.c').read_text()
for forbidden in ['unistd.h','sys/select.h','windows.h','ncurses.h']:
    assert forbidden not in ansi, forbidden
print('PASS host-neutral ANSI core')
