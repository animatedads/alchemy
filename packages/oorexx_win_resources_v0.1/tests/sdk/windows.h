// Stand-in for the Windows SDK windows.h: pulls in the stand-in winuser.h and
// the language ids the corpus uses.  Claude (Opus 5.5), 2026-11-14.
#ifndef OOREXX_WIN_RESOURCES_WINDOWS_H
#define OOREXX_WIN_RESOURCES_WINDOWS_H
#include "winuser.h"
#define LANG_NEUTRAL        0x00
#define LANG_ENGLISH        0x09
#define SUBLANG_NEUTRAL     0x00
#define SUBLANG_DEFAULT     0x01
#define SUBLANG_ENGLISH_US  0x01
#endif
