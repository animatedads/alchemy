#
# WMAKE-compatible MAKE file for building REXX/SQL with OpenWatcom C/C++ 1.2
#
# will generate:
#
#      rexxsql.dll
#      rexxsql.exe
#      rexx<db>.dll
#      rexx<db>.exe
#
# Usage: nmake [DEBUG=1]
#              [INT=REGINA|OREXX|WINREXX|QUERCUS]
#              [DB=SAW|ODBC|UDBC|ORA|MIN|DB2|MIN2|SOL|MY]
#              [rexxsql.dll|rexxsql.exe|rexx<db>.dll|rexx<db>.exe]
#
# ONLY TESTED WITH MySQL!!
#

SRC=$(%REXXSQL_SRCDIR)

!include $(SRC)\rexxsql.ver
VERDOT = $(VER_DOT)
VERDATE = $(VER_DATE)
#---------------------------------------------------------------------
# You should not have to change anything below here...
#---------------------------------------------------------------------

TARGET=NT
#
# Database specific defines
#
ORA_DBLIBS = $(%ORA_HOMEDIR)\lib\msvc\ociw32.lib
ORA_DBINC =
DB2_DBLIBS = $(%DB2_HOMEDIR)\lib\db2cli.lib
DB2_DBINC = -I$(%DB2_HOMEDIR)\include
SAW_DBLIBS = $(%SAW_HOMEDIR)\win32\lib\odbc32.lib
SAW_DBINC = -I$(%SAW_HOMEDIR)\h #/If:\sqlany50\h
MIN2_DBLIBS = $(%MIN2_HOMEDIR)\lib\msql_dll.lib wsock32.lib advapi32.lib
MIN2_DBINC = -I$(%MIN2_HOMEDIR)\include
MIN_DBLIBS = $(%MIN_HOMEDIR)\lib\msql_dll.lib wsock32.lib advapi32.lib
MIN_DBINC = -I$(%MIN_HOMEDIR)\include
ODBC_DBLIBS = odbc32.lib #$(ODBC_HOMEDIR)\odbc32.lib
ODBC_DBINC = #-I$(ODBC_HOMEDIR)
UDBC_DBLIBS = $(%UDBC_HOMEDIR)\lib\librpc.lib $(%UDBC_HOMEDIR)\lib\opludb32.lib wsock32.lib
UDBC_DBINC = -I$(%UDBC_HOMEDIR)\include /MT
#SOL_DBLIBS = $(SOL_HOMEDIR)\lib\SCLW3223.LIB
SOL_DBLIBS = $(%SOL_HOMEDIR)\lib\$(SOLLIB)
SOL_DBINC = -I$(%SOL_HOMEDIR)\include /DSS_NT /DSOLID_SERVER /DSS_EE
LITE_DBLIBS = $(%SQLITE_HOMEDIR)\lib\sqlite.lib
LITE_DBINC = -I$(%SQLITE_HOMEDIR)\include

!ifdef DEBUG
MY_DBLIBS = $(%MY_HOMEDIR)\lib\debug\libmysql.lib wsock32.lib advapi32.lib
MY_DBINC = /i=$(%MY_HOMEDIR)\include
!else
#MY_DBLIBS = $(%MY_HOMEDIR)\lib\opt\mysqlclient.lib wsock32.lib advapi32.lib
MY_DBLIBS = $(%MY_HOMEDIR)\lib\opt\libmysql.lib wsock32.lib advapi32.lib
MY_DBINC = /i=$(%MY_HOMEDIR)\include
!endif
#
!ifeq DB ORA
db = ora
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=ora
DBLIBS = e:\orant\bin\ociw32.lib
EXTRAINC =

!else
! ifeq DB DB2
db = db2
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = d:\sqllib\lib\db2cli.lib
EXTRAINC = /I=d:\sqllib\include

! else
!  ifeq DB SAW
db = saw
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = e:\mhes\odbcsdk.30\odbc32.lib
EXTRAINC = /I=e:\mhes\sqlany50\h

!  else
!   ifeq DB MIN

!   else
!    ifeq DB MIN2
db = min2
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
#DBLIBS = e:\public\msql2\lib\msql_dll.lib wsock32.lib advapi32.lib
DBLIBS = wsock32.lib,advapi32.lib
EXTRAINC = /I=e:\public\msql2\include

!    else
!     ifeq DB ODBC
db = odbc
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = e:\mhes\odbcsdk.30\odbc32.lib
EXTRAINC = /I=e:\mhes\odbcsdk.30

!     else
!      ifeq DB UDBC
db = udbc
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = e:\mhes\udbc\lib\librpc.lib,e:\mhes\udbc\lib\opludb32.lib,wsock32.lib #e:\mhes\udbc\lib\libudbc.lib
EXTRAINC = /I=e:\mhes\udbc\include

!      else
!       ifeq DB SOL
db = sol
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = e:\mhes\solid\lib\SCLW3222.LIB
EXTRAINC = /Ie:\mhes\solid\include /DSS_NT

!       else
!        ifeq DB MY
db = my
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\my
CLI=my
DBLIBS = $(MY_DBLIBS)
EXTRAINC = $(MY_DBINC)
!        else
!         error Target Database NOT specified via DB macro. Valid values are: ORA SAW ODBC MIN MIN2 DB2 SOL MY
!        endif
!       endif
!      endif
!     endif
!    endif
!   endif
!  endif
! endif
!endif

#
# Interpreter specific defines
#
!ifeq INT REGINA
REXXLIBS = $(%REGINA_BINDIR)\regina.lib
REXXINC = /I=$(%REGINA_SRCDIR) /DUSE_REGINA
!else
! ifeq INT OREXX
REXXLIBS = c:\objrexx\api\rexx.lib c:\objrexx\api\rexxapi.lib
REXXINC = /I=c:\objrexx\api /DUSE_OREXX
! else
!  ifeq INT WINREXX
REXXLIBS = e:\mhes\winrexx\api\rxrexx.lib
REXXINC = /I=e:\mhes\winrexx\api /DUSE_WINREXX
!  else
!   ifeq INT REXXTRANS
REXXLIBS = $(%REXXTRANS_BINDIR)\rexxtrans.lib
REXXINC = /I=$(%REXXTRANS_SRCDIR) /DUSE_REXXTRANS
!   else
!    error Rexx Interpreter NOT specified via INT macro. Valid values are: REGINA OREXX WINREXX REXXTRANS
!   endif
!  endif
! endif
!endif

EXTRALINK =
DBDEFINE = /D$(DB)_PREFIX
CCLIBS = user32.lib
DISTDIR=$(SRC)\dist

GETOPT = getopt.obj

INCCOMDIR = $(SRC)\common
INCGENDIR = $(SRC)\general
INCDBDIR = $(DBDIR)
INCSRCDIR = $(CLIDIR)

comcopts = /bm /zq /DWIN32 /DHAVE_PROTO /DREXXSQL_VERSION=$(VERDOT) /DREXXSQL_DATE=$(VERDATE) /i=$(DBDIR) /i=$(SRC)\common /i=$(SRC)\general $(REXXINC) $(EXTRAINC) # /4s /zp4 /ei /br
comlopts =

!ifdef DEBUG Y
copts  = $(comcopts) /d3 /DDEBUG
lopts  = $(comlopts) DEBUG ALL
!else
copts  = $(comcopts) /oneatx
lopts  = $(comlopts)
!endif

cflagsdll = $(copts) /bd /DDYNAMIC
cflagsexe = $(copts)
lflagsdll = $(lopts)
lflagsexe = $(lopts)

objssqldll = $(CLI)_dyn.obj rxpack_dyn.obj rxmt_win32_dyn.obj
objssqlexe = $(GETOPT) loader.obj $(CLI).obj rxpack.obj rxmt_win32.obj
objsdbdll = $(CLI)_$(db)_dyn.obj rxpack_dyn.obj rxmt_win32_$(db)_dyn.obj
objsdbexe = $(GETOPT) loader_$(db).obj $(CLI)_$(db).obj rxpack.obj rxmt_win32_$(db).obj

ccsqldll = wcc386 $(cflagsdll)
ccsqlexe = wcc386 $(cflagsexe)
ccdbdll = wcc386 $(cflagsdll) $(DBDEFINE)
ccdbexe = wcc386 $(cflagsexe) $(DBDEFINE)

H1=$(INCGENDIR)\rexxsql.h $(INCCOMDIR)\defines.h
H2=$(INCDBDIR)\dbdefine.h $(INCDBDIR)\dbheader.h $(INCDBDIR)\dbtypes.h
H3=$(INCGENDIR)\rxsqlinc1.h $(INCGENDIR)\rxsqlinc2.h
H4=#$(INCGENDIR)\hash.h
H5=$(INCCOMDIR)\rxpack.h $(INCCOMDIR)\rxdef.h
H6=$(INCCOMDIR)\rxmt_win32.h $(INCCOMDIR)\rxmt.h
H7=$(INCCOMDIR)\rxmt_notmt.h $(INCCOMDIR)\rxmt.h

all: rexxsql.exe rexxsql.dll rexx$(db).exe rexx$(db).dll

getopt.obj: $(INCCOMDIR)\getopt.c
	$(ccsqlexe) /fo=$^@ $(INCCOMDIR)\getopt.c

rxpack.obj: $(INCCOMDIR)\rxpack.c $(H5)
	$(ccsqlexe) $(sqlcflags) /fo=$^@ $(INCCOMDIR)\rxpack.c

rxpack_dyn.obj: $(INCCOMDIR)\rxpack.c $(H5)
	$(ccsqldll) /fo=$^@ $(sqlcflags) $(INCCOMDIR)\rxpack.c

rxmt_win32.obj: $(INCCOMDIR)\rxmt_win32.c $(H6)
	$(ccsqlexe) /fo=$^@ $(sqlcflags) $(INCCOMDIR)\rxmt_win32.c

rxmt_win32_dyn.obj: $(INCCOMDIR)\rxmt_win32.c $(H6)
	$(ccsqldll) /fo=$^@ $(sqlcflags) $(INCCOMDIR)\rxmt_win32.c

rxmt_win32_$(db)_dyn.obj: $(INCCOMDIR)\rxmt_win32.c $(H6)
	$(ccsqldll) /fo=$^@ $(dbcflags) $(INCCOMDIR)\rxmt_win32.c

rxmt_win32_$(db).obj: $(INCCOMDIR)\rxmt_win32.c $(H6)
	$(ccsqlexe) /fo=$^@ $(dbcflags) $(INCCOMDIR)\rxmt_win32.c

rxmt_notmt.obj: $(INCCOMDIR)\rxmt_notmt.c $(H7)
	$(ccsqlexe) /fo=$^@ $(sqlcflags) $(INCCOMDIR)\rxmt_notmt.c

rxmt_notmt_$(db).obj: $(INCCOMDIR)\rxmt_notmt.c $(H7)
	$(ccsqlexe) /fo=$^@ $(dbcflags) $(INCCOMDIR)\rxmt_notmt.c

loader.obj: $(INCCOMDIR)\loader.c $(H1) $(H2)
	$(ccsqlexe) /fo=$^@ $(sqlcflags) $(INCCOMDIR)\loader.c

loader_$(db).obj: $(INCCOMDIR)\loader.c $(H1) $(H2)
	$(ccdbexe) /fo=$^@ $(dbcflags) $(INCCOMDIR)\loader.c

rexxsql_dyn.obj: $(INCGENDIR)\rexxsql.c $(H1) $(H2)
	$(ccsqldll) /fo=$^@ $(sqlcflags) $(INCGENDIR)\rexxsql.c

rexxsql_$(db)_dyn.obj: $(INCGENDIR)\rexxsql.c $(H1) $(H2)
	$(ccdbdll) /fo=$^@ $(dbcflags) $(INCGENDIR)\rexxsql.c

$(CLI).obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(ccsqlexe) /fo=$^@ $(sqlcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_$(db).obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(ccdbexe) /fo=$^@ $(dbcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_dyn.obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(ccsqldll) /fo=$^@ $(sqlcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_$(db)_dyn.obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(ccdbdll) /fo=$^@ $(dbcflags) $(INCSRCDIR)\$(CLI).c


rexxsql.exe: $(objssqlexe)
	@%create rexxsql.lnk
	@%append rexxsql.lnk option quiet
	@%append rexxsql.lnk system $(TARGET)
	@%append rexxsql.lnk name rexxsql.exe
	for %i in ($(objssqlexe)) do %append rexxsql.lnk FILE %i
	for %i in ($(DBLIBS)) do %append rexxsql.lnk LIBRARY %i
	for %i in ($(REXXLIBS)) do %append rexxsql.lnk LIBRARY %i
	wlink $(lflagsexe) @rexxsql.lnk
	del rexxsql.lnk

rexx$(DB).exe: $(objsdbexe)
	@%create rexxsql.lnk
	@%append rexxsql.lnk option quiet
	@%append rexxsql.lnk system $(TARGET)
	@%append rexxsql.lnk name rexx$(DB).exe
	for %i in ($(objsdbexe)) do %append rexxsql.lnk FILE %i
	for %i in ($(DBLIBS)) do %append rexxsql.lnk LIBRARY %i
	for %i in ($(REXXLIBS)) do %append rexxsql.lnk LIBRARY %i
	wlink $(lflagsexe) @rexxsql.lnk
	del rexxsql.lnk

rexxsql.dll: $(objssqldll)
	@%create rexxsql.lnk
	@%append rexxsql.lnk option quiet
	@%append rexxsql.lnk system $(TARGET) dll
	@%append rexxsql.lnk name rexxsql.dll
	for %i in ($(objssqldll)) do %append rexxsql.lnk FILE %i
	for %i in ($(DBLIBS)) do %append rexxsql.lnk LIBRARY %i
	for %i in ($(REXXLIBS)) do %append rexxsql.lnk LIBRARY %i
	%append rexxsql.lnk export SQLLoadFuncs='_SQLLoadFuncs@20'
	%append rexxsql.lnk export RexxSQLDropFuncs='_RexxSQLDropFuncs@20'
	%append rexxsql.lnk export RexxSQLConnect='_RexxSQLConnect@20'
	%append rexxsql.lnk export RexxSQLDisconnect='_RexxSQLDisconnect@20'
	%append rexxsql.lnk export RexxSQLCommand='_RexxSQLCommand@20'
	%append rexxsql.lnk export RexxSQLVariable='_RexxSQLVariable@20'
	%append rexxsql.lnk export RexxSQLDefault='_RexxSQLDefault@20'
	%append rexxsql.lnk export RexxSQLCommit='_RexxSQLCommit@20'
	%append rexxsql.lnk export RexxSQLRollback='_RexxSQLRollback@20'
	%append rexxsql.lnk export RexxSQLPrepare='_RexxSQLPrepare@20'
	%append rexxsql.lnk export RexxSQLDispose='_RexxSQLDispose@20'
	%append rexxsql.lnk export RexxSQLOpen='_RexxSQLOpen@20'
	%append rexxsql.lnk export RexxSQLExecute='_RexxSQLExecute@20'
	%append rexxsql.lnk export RexxSQLClose='_RexxSQLClose@20'
	%append rexxsql.lnk export RexxSQLFetch='_RexxSQLFetch@20'
	%append rexxsql.lnk export RexxSQLGetInfo='_RexxSQLGetInfo@20'
	%append rexxsql.lnk export RexxSQLGetData='_RexxSQLGetData@20'
	%append rexxsql.lnk export RexxSQLDescribe='_RexxSQLDescribe@20'
	%append rexxsql.lnk export RexxSQLDataSources='_RexxSQLDataSources@20'
	%append rexxsql.lnk export RexxSQLTables='_RexxSQLTables@20'
	%append rexxsql.lnk export RexxSQLColumns='_RexxSQLColumns@20'
	wlink $(lflagsdll) @rexxsql.lnk
	del rexxsql.lnk

rexx$(DB).dll: $(objsdbdll)
	@%create rexxsql.lnk
	@%append rexxsql.lnk option quiet
	@%append rexxsql.lnk system $(TARGET) dll
	@%append rexxsql.lnk name rexx$(DB).dll
	for %i in ($(objsdbdll)) do %append rexxsql.lnk FILE %i
	for %i in ($(DBLIBS)) do %append rexxsql.lnk LIBRARY %i
	for %i in ($(REXXLIBS)) do %append rexxsql.lnk LIBRARY %i
	%append rexxsql.lnk export $(DB)LoadFuncs='_$(DB)LoadFuncs@20'
	%append rexxsql.lnk export Rexx$(DB)DropFuncs='_Rexx$(DB)DropFuncs@20'
	%append rexxsql.lnk export Rexx$(DB)Connect='_Rexx$(DB)Connect@20'
	%append rexxsql.lnk export Rexx$(DB)Disconnect='_Rexx$(DB)Disconnect@20'
	%append rexxsql.lnk export Rexx$(DB)Command='_Rexx$(DB)Command@20'
	%append rexxsql.lnk export Rexx$(DB)Variable='_Rexx$(DB)Variable@20'
	%append rexxsql.lnk export Rexx$(DB)Default='_Rexx$(DB)Default@20'
	%append rexxsql.lnk export Rexx$(DB)Commit='_Rexx$(DB)Commit@20'
	%append rexxsql.lnk export Rexx$(DB)Rollback='_Rexx$(DB)Rollback@20'
	%append rexxsql.lnk export Rexx$(DB)Prepare='_Rexx$(DB)Prepare@20'
	%append rexxsql.lnk export Rexx$(DB)Dispose='_Rexx$(DB)Dispose@20'
	%append rexxsql.lnk export Rexx$(DB)Open='_Rexx$(DB)Open@20'
	%append rexxsql.lnk export Rexx$(DB)Execute='_Rexx$(DB)Execute@20'
	%append rexxsql.lnk export Rexx$(DB)Close='_Rexx$(DB)Close@20'
	%append rexxsql.lnk export Rexx$(DB)Fetch='_Rexx$(DB)Fetch@20'
	%append rexxsql.lnk export Rexx$(DB)GetInfo='_Rexx$(DB)GetInfo@20'
	%append rexxsql.lnk export Rexx$(DB)GetData='_Rexx$(DB)GetData@20'
	%append rexxsql.lnk export Rexx$(DB)Describe='_Rexx$(DB)Describe@20'
	%append rexxsql.lnk export Rexx$(DB)DataSources='_Rexx$(DB)DataSources@20'
	%append rexxsql.lnk export Rexx$(DB)Tables='_Rexx$(DB)Tables@20'
	%append rexxsql.lnk export Rexx$(DB)Columns='_Rexx$(DB)Columns@20'
	wlink $(lflagsdll) @rexxsql.lnk
	del rexxsql.lnk

dist: rexxsql.exe rexxsql.dll rexx$(db).exe rexx$(db).dll
	copy *.exe $(DISTDIR)\$(DB)\$(INT)
	copy *.dll $(DISTDIR)\$(DB)\$(INT)
	copy rexx$(db).exe $(DISTDIR)\$(DB)\$(INT)
	copy rexx$(db).dll $(DISTDIR)\$(DB)\$(INT)
