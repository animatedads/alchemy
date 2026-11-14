# Upstream ooDialog sample resources: provenance

- **Source:** the 26 `.rc` files listed in `packages/oorexx_rc_executable_tree/corpus/official_oodialog.txt`, from the ooRexx GitHub mirror (`github.com/ooRexx/ooRexx`) at commit `c12e988` (13 Nov 2026). ooRexx is © the Rexx Language Association and released under the Common Public License 1.0. These compiled resources are derived from it and carry the same licence.
- **Compiled by:** `build_upstream_corpus.sh` on 14 Nov 2026, with llvm-rc 18. The script changes Windows `\\` path separators to `/` in a copy, never in the original. The SDK constants come from the stand-in headers in `../sdk`.
- **Result:** 24 of 26 compile, listed in `res/SHA256SUMS`. The other 2 fail on upstream defects, recorded in `res/FAILURES.txt`:
  - `controls/ListView/rc/customDrawListView.rc` includes `"customDraw.h"`, but upstream ships only `customDrawListView.h`.
  - `rc/oodStandardDialogs.rc` uses the icon `oodStandardDialog.ico`, but upstream ships `oodStandardDialogs.ico`.
- **Check:** `rexx tools/res_corpus_check.rex --dir tests/corpus/res --readobj` read 50 resources: 44 dialogs with 534 controls, and 3 menus. There were 0 decode errors, and 0 differences from `llvm-cvtres` + `llvm-readobj --coff-resources` in type, name, language and size.
- **Control kinds:** STATIC 162, EDIT 126, BUTTON 81, RADIO 72, GROUP 42, UPDOWN 16, LISTVIEW 14, CHECK 9, COMBO 5, TREEVIEW 4, DATETIMEPICKER 2, LIST 1. Not in the contract: 2 `ToolbarWindow32`.

Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
