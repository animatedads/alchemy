#
# NMAKE-compatible MAKE file for building REXX/SQL with C Set/2
#
# will generate:
#
#      rexxsql.dll
#      rexxsql.exe
#      rexx<db>.dll
#      rexx<db>.exe
# 
# Usage: nmake [DEBUG=1] 
#              [DB=SAW|ODBC|UDBC|ORA|MIN|DB2|SYB|MIN2|SOL]
#              [LOAD=DYNAMIC]
#              [rexxsql.dll|rexxsql.exe|rexx<db>.dll|rexx<db>.exe]
#

SRC = c:\RexxSQL-2.4
#---------------------------------------------------------------------
# You should not have to change anything below here...
#---------------------------------------------------------------------
!if "$(LOAD)" == "DYNAMIC"
DYNLOAD=/DDYNAMIC_LOAD
!else
DYNLOAD=
!endif

#
# Database specific defines
#
!if "$(DB)" == "ORA"
db = ora
DBDEFINE = /DORA_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=ora
DBLIBS = rexx+ora7o32
EXTRAINC =

!else
! if "$(DB)" == "DB2"
db = db2
DBDEFINE = /DDB2_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+db2cli
EXTRAINC =

! else
!  if "$(DB)" == "SAW"
db = saw
DBDEFINE = /DSAW_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+c:\sqlany50\os2\lib\wodbc2.lib
EXTRAINC = /Ic:\sqlany50\h

!  else
!   if "$(DB)" == "MIN"
db = min
DBDEFINE = /DMIN_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
DBLIBS = rexx+i:\public\msql\lib\msql_dll.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
EXTRAINC = /Ic:\public\msql\include

!   else
!    if "$(DB)" == "MIN2"
db = min
DBDEFINE = /DMIN_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
!    if "$(LOAD)" == "DYNAMIC"
DBLIBS = rexx++f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
!    else
#DBLIBS = rexx+h:\public\msql2\lib\msql.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
#DBLIBS = rexx+msql_dll.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
DBLIBS = rexx+c:\public\msql2\lib\msql_dll.lib+c:\tcpip\lib\so32dll.lib+c:\tcpip\lib\tcp32dll.lib
!    endif
EXTRAINC = /Ic:\public\msql2\include

!    else
!     if "$(DB)" == "ODBC"
db = odbc
DBDEFINE = /DODBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+e:\mhes\odbcsdk.30\odbc32.lib
EXTRAINC = /Ie:\mhes\odbcsdk.30

!     else
!      if "$(DB)" == "UDBC"
db = udbc
DBDEFINE = /DUDBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+h:\udbc\lib\opludbc.lib
EXTRAINC = /Ih:\udbc\include

!      else
!       if "$(DB)" == "SYB"
db = syb
DBDEFINE = /DSYB_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=syb
DBLIBS = rexx+e:\sql10\lib\libct+e:\sql10\lib\libcs
EXTRAINC = /Ie:\sql10\include
!       else
!        if "$(DB)" == "SOL"
db = sol
DBDEFINE = /DSOL_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+h:\ss\lib\SCLO3222.LIB
EXTRAINC = /Ih:\ss\include /DSOLID_SERVER
!        else
!          error Target Database NOT specified via DB macro. Valid values are: ORA SAW ODBC MIN MIN2 DB2 SYB SOL
!        endif
!       endif
!      endif
!     endif
!    endif
!   endif
!  endif
! endif
!endif

EXTRALINK =
DISTDIR=$(SRC)\dist

#comcopts = /C /Ms /Gm- /Q /Sm /DHAVE_PROTO /J+ /I$(DBDIR) /I$(SRC)\common $(EXTRAINC) $(DYNLOAD)
comcopts = /C /Ms /Gm /Gf /Q /Sm /DUSE_OS2REXX /DHAVE_PROTO /J+ /I$(DBDIR) /I$(SRC)\common $(EXTRAINC) $(DYNLOAD)
comlopts = /NOI /NOE /NOLOGO /EXEPACK:2 /ALIGN:4 $(EXTRALINK)

!ifdef DEBUG
copts  = $(comcopts) /Ti+ /O- /DDEBUG
lopts  = $(comlopts) /DEBUG /MAP:FULL
!else
copts  = $(comcopts) /Ti- /O+
lopts  = $(comlopts) /PACKCODE /PACKDATA
!endif

cflagsdll = $(copts) /Ge- /DDYNAMIC
cflagsexe = $(copts) /Ge+
lflagsdll = $(lopts)
lflagsexe = $(lopts) /ST:128000 /SE:512

objssqldll = hashdll.obj utsqldll.obj rxsqldll.obj rxpackdll.obj
objssqlexe = getopt.obj hashexe.obj utsqlexe.obj rxsqlexe.obj rxpackexe.obj loader.obj
objsdbdll = hashdll.obj ut$(db)dll.obj rx$(db)dll.obj rxpackdll.obj
objsdbexe = getopt.obj hashexe.obj ut$(db)exe.obj rx$(db)exe.obj loader.obj rxpackexe.obj

ccsqldll = icc $(cflagsdll) $(listopt)
ccsqlexe = icc $(cflagsexe) $(listopt)
ccdbdll = icc $(cflagsdll) $(listopt) $(DBDEFINE)
ccdbexe = icc $(cflagsexe) $(listopt) $(DBDEFINE)

H1=$(SRC)\common\rexxsql.h
H2=$(DBDIR)\dbdefine.h
H3=$(DBDIR)\dbheader.h
H4=$(DBDIR)\dbtypes.h
H5=$(SRC)\common\hash.h
H6=$(SRC)\common\rxpack.h

all: rexxsql.dll rexxsql.exe rexx$(db).dll dist #rexx$(db).exe

#
# These function only required for EXE
#
getopt.obj: $(SRC)\common\getopt.c
    $(ccsqlexe) /Fogetopt.obj $(SRC)\common\getopt.c

loader.obj: $(SRC)\common\loader.c $(H1) $(H2)
    $(ccsqlexe) /Foloader.obj $(SRC)\common\loader.c

#
# These functions required for both EXE and DLL
# Same file used for standard and DB-specific binary
#
hashdll.obj: $(SRC)\common\hash.c $(H5)
    $(ccsqldll) /Fohashdll.obj $(SRC)\common\hash.c

hashexe.obj: $(SRC)\common\hash.c $(H5)
    $(ccsqlexe) /Fohashexe.obj $(SRC)\common\hash.c

rxpackdll.obj: $(SRC)\common\rxpack.c $(H6)
    $(ccsqldll) /Forxpackdll.obj $(SRC)\common\rxpack.c

rxpackexe.obj: $(SRC)\common\rxpack.c $(H6)
    $(ccsqlexe) /Forxpackexe.obj $(SRC)\common\rxpack.c
#
# These functions required for both EXE and DLL
# Different file used for standard and DB-specific binary
#

rxsqldll.obj: $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3) $(H4) $(H5)
    $(ccsqldll) /Forxsqldll.obj $(CLIDIR)\$(CLI).c

rxsqlexe.obj: $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3) $(H4) $(H5)
    $(ccsqlexe) /Forxsqlexe.obj $(CLIDIR)\$(CLI).c

rx$(db)dll.obj: $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3) $(H4) $(H5)
    $(ccdbdll) /Forx$(db)dll.obj $(CLIDIR)\$(CLI).c

rx$(db)exe.obj: $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3) $(H4) $(H5)
    $(ccdbexe) /Forx$(db)exe.obj $(CLIDIR)\$(CLI).c

utsqldll.obj: $(SRC)\common\util.c $(H1) $(H2) $(H5)
    $(ccsqldll) /Foutsqldll.obj $(SRC)\common\util.c

utsqlexe.obj: $(SRC)\common\util.c $(H1) $(H2) $(H5)
    $(ccsqlexe) /Foutsqlexe.obj $(SRC)\common\util.c

ut$(db)dll.obj: $(SRC)\common\util.c $(H1) $(H2) $(H5)
    $(ccdbdll) /Fout$(db)dll.obj $(SRC)\common\util.c

ut$(db)exe.obj: $(SRC)\common\util.c $(H1) $(H2) $(H5)
    $(ccdbexe) /Fout$(db)exe.obj $(SRC)\common\util.c


rexxsql.dll: $(objssqldll)
	link386 $(lflagsdll) utsqldll.obj+hashdll.obj+rxsqldll.obj+rxpackdll.obj,$@,$*.map,$(DBLIBS),$(SRC)\rexxsql_os2_dll.def;
	rc $(SRC)\rexxsql_os2.res rexxsql.dll

rexxsql.exe: $(objssqlexe)
	link386 $(lflagsexe) utsqlexe.obj+loader.obj+hashexe.obj+rxsqlexe.obj+getopt.obj+rxpackexe.obj,$@,$*.map,$(DBLIBS),$(SRC)\rexxsql_os2_exe.def;
	rc $(SRC)\rexxsql_os2.res rexxsql.exe

rexx$(db).dll: $(objsdbdll)
	link386 $(lflagsdll) ut$(db)dll.obj+hashdll.obj+rx$(db)dll.obj+rxpackdll.obj,$@,$*.map,$(DBLIBS),$(SRC)\rexx$(db)_os2_dll.def;
	rc $(SRC)\rexxsql_os2.res rexx$(db).dll

rexx$(db).exe: $(objsdbexe)
	link386 $(lflagsexe) ut$(db)exe.obj+loader.obj+hashexe.obj+rx$(db)exe.obj+getopt.obj+rxpackexe.obj,$@,$*.map,$(DBLIBS),$(SRC)\rexx$(db)_os2_exe.def;
	rc $(SRC)\rexxsql_os2.res rexx$(db).exe

dist: $(DISTDIR)\$(DB)\rexxsql.exe $(DISTDIR)\$(DB)\rexxsql.dll $(DISTDIR)\$(DB)\rexx$(db).exe $(DISTDIR)\$(DB)\rexx$(db).dll

$(DISTDIR)\$(DB)\rexxsql.exe: rexxsql.exe
	copy rexxsql.exe $(DISTDIR)\$(DB)

$(DISTDIR)\$(DB)\rexxsql.dll: rexxsql.dll
	copy rexxsql.dll $(DISTDIR)\$(DB)

$(DISTDIR)\$(DB)\rexx$(db).exe: rexx$(db).exe
	copy rexx$(db).exe $(DISTDIR)\$(DB)

$(DISTDIR)\$(DB)\rexx$(db).dll: rexx$(db).dll
	copy rexx$(db).dll $(DISTDIR)\$(DB)
