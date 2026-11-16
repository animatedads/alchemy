// The Win32 style constants app.rc uses (values from the Windows SDK
// winuser.h and commctrl.h), so the fixture builds without the SDK.
#define WS_POPUP            0x80000000L
#define WS_CHILD            0x40000000L
#define WS_VISIBLE          0x10000000L
#define WS_DISABLED         0x08000000L
#define WS_CAPTION          0x00C00000L
#define WS_BORDER           0x00800000L
#define WS_VSCROLL          0x00200000L
#define WS_HSCROLL          0x00100000L
#define WS_SYSMENU          0x00080000L
#define WS_THICKFRAME       0x00040000L
#define WS_GROUP            0x00020000L
#define WS_TABSTOP          0x00010000L
#define WS_MINIMIZEBOX      0x00020000L
#define WS_MAXIMIZEBOX      0x00010000L

#define DS_SYSMODAL         0x0002L
#define DS_SETFONT          0x0040L
#define DS_MODALFRAME       0x0080L
#define DS_CENTER           0x0800L

#define BS_LEFTTEXT         0x0020L
#define SS_NOTIFY           0x0100L
#define SS_GRAYFRAME        0x0008L
#define SS_WHITERECT        0x0006L
#define SS_ETCHEDHORZ       0x0010L

#define ES_MULTILINE        0x0004L
#define ES_PASSWORD         0x0020L
#define ES_AUTOHSCROLL      0x0080L
#define ES_READONLY         0x0800L
#define ES_WANTRETURN       0x1000L
#define ES_NUMBER           0x2000L

#define LBS_SORT            0x0002L
#define LBS_NOINTEGRALHEIGHT 0x0100L
#define LBS_EXTENDEDSEL     0x0800L

#define CBS_SIMPLE          0x0001L
#define CBS_DROPDOWNLIST    0x0003L
#define CBS_SORT            0x0100L

#define PBS_SMOOTH          0x01
#define PBS_VERTICAL        0x04
#define LVS_REPORT          0x0001
#define LVS_SINGLESEL       0x0004
#define TVS_HASBUTTONS      0x0001
#define TVS_HASLINES        0x0002
#define TVS_LINESATROOT     0x0004
#define TCS_MULTILINE       0x0200
#define UDS_SETBUDDYINT     0x0002
#define UDS_ALIGNRIGHT      0x0004
#define UDS_AUTOBUDDY       0x0010
#define UDS_ARROWKEYS       0x0020
#define TBS_AUTOTICKS       0x0001
#define TBS_VERT            0x0002
#define DTS_TIMEFORMAT      0x0009

#define MFT_SEPARATOR       0x00000800L
#define MFT_RADIOCHECK      0x00000200L
#define MFT_RIGHTJUSTIFY    0x00004000L
#define MFS_GRAYED          0x00000003L
#define MFS_CHECKED         0x00000008L
#define MFS_DEFAULT         0x00001000L
