// Stand-in for the Windows SDK commctrl.h: the common-control class names
// and styles the ooDialog sample corpus uses, with the SDK's values.
// Claude (Opus 5.5), 2026-11-14.
#ifndef OOREXX_WIN_RESOURCES_COMMCTRL_H
#define OOREXX_WIN_RESOURCES_COMMCTRL_H

#define WC_BUTTON           "Button"
#define WC_STATIC           "Static"
#define WC_EDIT             "Edit"
#define WC_LISTBOX          "ListBox"
#define WC_COMBOBOX         "ComboBox"
#define WC_LISTVIEW         "SysListView32"
#define WC_TREEVIEW         "SysTreeView32"
#define WC_TABCONTROL       "SysTabControl32"
#define PROGRESS_CLASS      "msctls_progress32"
#define TRACKBAR_CLASS      "msctls_trackbar32"
#define UPDOWN_CLASS        "msctls_updown32"
#define DATETIMEPICK_CLASS  "SysDateTimePick32"
#define MONTHCAL_CLASS      "SysMonthCal32"
#define TOOLBARCLASSNAME    "ToolbarWindow32"

#define CCS_TOP             0x00000001L
#define CCS_NOMOVEY         0x00000002L
#define CCS_BOTTOM          0x00000003L
#define CCS_NORESIZE        0x00000004L
#define CCS_NOPARENTALIGN   0x00000008L
#define CCS_ADJUSTABLE      0x00000020L
#define CCS_NODIVIDER       0x00000040L
#define CCS_VERT            0x00000080L

#define LVS_ICON            0x0000
#define LVS_REPORT          0x0001
#define LVS_SMALLICON       0x0002
#define LVS_LIST            0x0003
#define LVS_SINGLESEL       0x0004
#define LVS_SHOWSELALWAYS   0x0008
#define LVS_SORTASCENDING   0x0010
#define LVS_SORTDESCENDING  0x0020
#define LVS_SHAREIMAGELISTS 0x0040
#define LVS_NOLABELWRAP     0x0080
#define LVS_AUTOARRANGE     0x0100
#define LVS_EDITLABELS      0x0200
#define LVS_ALIGNTOP        0x0000
#define LVS_ALIGNLEFT       0x0800
#define LVS_NOCOLUMNHEADER  0x4000
#define LVS_NOSORTHEADER    0x8000

#define TVS_HASBUTTONS      0x0001
#define TVS_HASLINES        0x0002
#define TVS_LINESATROOT     0x0004
#define TVS_EDITLABELS      0x0008
#define TVS_DISABLEDRAGDROP 0x0010
#define TVS_SHOWSELALWAYS   0x0020
#define TVS_NOTOOLTIPS      0x0080
#define TVS_CHECKBOXES      0x0100
#define TVS_TRACKSELECT     0x0200
#define TVS_INFOTIP         0x0800
#define TVS_FULLROWSELECT   0x1000

#define UDS_WRAP            0x0001
#define UDS_SETBUDDYINT     0x0002
#define UDS_ALIGNRIGHT      0x0004
#define UDS_ALIGNLEFT       0x0008
#define UDS_AUTOBUDDY       0x0010
#define UDS_ARROWKEYS       0x0020
#define UDS_HORZ            0x0040
#define UDS_NOTHOUSANDS     0x0080
#define UDS_HOTTRACK        0x0100

#define DTS_UPDOWN          0x0001
#define DTS_SHOWNONE        0x0002
#define DTS_SHORTDATEFORMAT 0x0000
#define DTS_LONGDATEFORMAT  0x0004
#define DTS_SHORTDATECENTURYFORMAT 0x000C
#define DTS_TIMEFORMAT      0x0009
#define DTS_APPCANPARSE     0x0010
#define DTS_RIGHTALIGN      0x0020

#define TBSTYLE_TOOLTIPS    0x0100
#define TBSTYLE_WRAPABLE    0x0200
#define TBSTYLE_ALTDRAG     0x0400
#define TBSTYLE_FLAT        0x0800
#define TBSTYLE_LIST        0x1000

#endif
