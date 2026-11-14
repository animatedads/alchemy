# oorexx_win_resources v0.1

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), 14 Nov 2026
- **Written by:** Claude (Opus 5.5)

This package reads binary Windows resources in pure ooRexx. One file, `src/WinResources.cls`, with no native code, so it runs unchanged on ooRexx/WASM. It is the reader that ooDialog/WASM v0.3.0 plugs in for `ResDialog` and `BinaryMenuBar`:

```rexx
.oodn~resourceProvider = .WinResourceProvider~new        -- or ~new(1031) to prefer a language
```

## What it reads

| Container | How |
|---|---|
| `.res` (rc.exe, windres, llvm-rc) | `RESOURCEHEADER` records, DWORD-aligned; the empty first record is skipped |
| `.dll` / `.exe` | `MZ` → `PE` → data directory 2 → the Type → Name → Language tree of `.rsrc`; PE32 and PE32+ |

The format is detected from the content, not from the file name.

| Template | Decoded |
|---|---|
| `DIALOG`, `DIALOGEX` | geometry in dialog units, title, font (size, weight, italic, face), and every item: class, id (`IDC_STATIC` is -1), styles, text or ordinal, creation data |
| `MENU`, `MENUEX` | flattened depth first: depth, id, text, flags; nested popups, separators, `MFT_RADIOCHECK`, `MFS_DEFAULT`, `MF_HELP` |

Text is stored in UTF-16LE, and this reader returns UTF-8, surrogate pairs included. Names compare without regard to case. Language choice is the one asked for, then neutral, then en-US, then the first found.

## The ooDialog/WASM contract

The contract is in `animatedads/oorexx`, `oodialog-wasm/src/oodWeb.cls`, in the comment above `resourceProvider`.

- `dialogTemplate(library, id)` returns `x y cx cy title opts fontName fontSize controls`. Each control has `kind id x y cx cy text opts`.
- `menuTemplate(library, id)` returns records of `depth id text flags`.

Window classes map to the contract's 16 kinds. `BUTTON` splits by `BS_` type into BUTTON, CHECK, RADIO and GROUP, and `STATIC` frames and rectangles become FRAME. Styles become the words the page runtime reads: `DEFAULT 3STATE LTEXT NOTAB GROUP HIDDEN DISABLED MULTILINE NOWANTRETURN PASSWORD READONLY SORT MULTI LIST SIMPLE VERTICAL REPORT SINGLESEL RECT GRAY WHITE ETCHED …`. See `WinDialogItem~opts`.

Fields beyond the contract are for provenance and are ignored by the consumer:

- raw `style` and `exStyle` in hex;
- `windowClass`;
- `resource`, the ordinal of an `SS_ICON` image;
- `unsupported`: the controls the contract has no kind for, today the month calendar and the scroll bar. They are listed there, not dropped silently.

## Tests

```
rexx packages/oorexx_win_resources_v0.1/tests/test_win_resources.rex
```

There are 46 checks against `tests/fixtures/app.rc`, compiled by **llvm-rc 18** into `app.res` and linked by **lld-link** into `app.dll`. `llvm-readobj --coff-resources` independently lists the same 7 resources. `tests/fixtures/build.sh` rebuilds both binaries, and `SHA256SUMS` pins them. The checks cover:

- the `.res` and `.dll` give identical answers for every template;
- dialog 100 and menu 300 return exactly what t06's stand-in returns;
- every contract kind and its style words;
- a UTF-16 title containing ß, € and 𝄞;
- language choice;
- named resources;
- absent ids, missing files, and truncated or non-PE input, which raise errors instead of looping.

Not covered: a resource compiled by Microsoft `rc.exe` (no Windows here), 16-bit NE files, and `DLGINIT` data.

## Handoff to ooDialog/WASM: `integration/oodialog_wasm/`

`t07_resdialog_binary.rex` is t06 with one change: the stand-in reader is replaced by this reader, reading the real `app.dll`. It uses the same `.steps` and the same `.expect`. To run it in the oodialog-wasm harness:

1. Put `WinResources.cls` in the page file system next to `ooDialog.cls`.
2. Put `app.dll` next to the test.
3. `tools/oodtest.py` currently reads every file with `read_text(encoding='latin-1')`. A `.dll` must reach the WASM file system as bytes, so the harness needs a binary path.
