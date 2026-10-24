#
# NMAKE-compatible MAKE file for building REXX/SQL with VisulaAge C++
#
# will generate:
#
#      rexxsql.dll
#      rexxsql.exe
#      rexx<db>.dll
#      rexx<db>.exe
# 
# Usage: nmake [DEBUG=1] 
#              [DB=MY|SAW|ODBC|UDBC|ORA|MIN|DB2|SYB|MIN2|SOL]
#              [LOAD=DYNAMIC]
#              [rexxsql.dll|rexxsql.exe|rexx<db>.dll|rexx<db>.exe]
#

SRC = \rexxsql
#---------------------------------------------------------------------
# You should not have to change anything below here...
#---------------------------------------------------------------------
!if "$(INT)" == "REXXTRANS"
INTINC=/DUSE_REXXTRANS /I$(REXXTRANS_SRCDIRN)
INTLIB=$(REXXTRANS_BINDIRN)\rexxtran.lib
!else
INTINC=/DUSE_OS2REXX
INTLIB=rexx.lib
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
DBLIBS = $(INTLIB)+ora7o32
EXTRAINC =

!else
! if "$(DB)" == "DB2"
db = db2
DBDEFINE = /DDB2_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(INTLIB)+\sqllib\lib\db2cli
EXTRAINC =

! else
!  if "$(DB)" == "SAW"
db = saw
DBDEFINE = /DSAW_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(INTLIB)+wodbc2
EXTRAINC = /Ih:\sqlany50\h

!  else
!   if "$(DB)" == "MIN"
db = min
DBDEFINE = /DMIN_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
DBLIBS = $(INTLIB)+i:\public\msql\lib\msql_dll.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
EXTRAINC = /Ii:\public\msql\include

!   else
!    if "$(DB)" == "MIN2"
db = min
DBDEFINE = /DMIN_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
#DBLIBS = rexx+h:\public\msql2\lib\msql.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
#DBLIBS = rexx+msql_dll.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
DBLIBS = $(INTLIB)+h:\public\msql2\lib\msql_dll.lib+f:\tcpip\lib\so32dll.lib+f:\tcpip\lib\tcp32dll.lib
EXTRAINC = /Ih:\public\msql2\include

!    else
!     if "$(DB)" == "ODBC"
db = odbc
DBDEFINE = /DODBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(INTLIB)+c:\odbc\lib\odbc.lib
EXTRAINC = /Ic:\odbc\include

!    else
!     if "$(DB)" == "MY"
db = my
DBDEFINE = /DMY_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=my
DBLIBS = $(INTLIB)+c:\usr\local\mysql\lib\mysql.lib
EXTRAINC = /Ic:\usr\local\mysql\include

!     else
!      if "$(DB)" == "UDBC"
db = udbc
DBDEFINE = /DUDBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(INTLIB)+h:\udbc\lib\opludbc.lib
EXTRAINC = /Ih:\udbc\include

!      else
!       if "$(DB)" == "SYB"
db = syb
DBDEFINE = /DSYB_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=syb
DBLIBS = $(INTLIB)+e:\sql10\lib\libct+e:\sql10\lib\libcs
EXTRAINC = /Ie:\sql10\include
!       else
!        if "$(DB)" == "SOL"
db = sol
DBDEFINE = /DSOL_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(INTLIB)+h:\ss\lib\SCLO3222.LIB
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
! endif
!endif

EXTRALINK =
DISTDIR=$(SRC)\dist

comcopts = /C /Ms /Gm+ /Gp /Gf /Q /Se /DOS2ODBC $(INTINC) /DHAVE_PROTO /J+ /I$(DBDIR) /I$(SRC)\common /I$(SRC)\general $(EXTRAINC) $(DYNLOAD) #/Gm- is single thread
comlopts = /NOFREE /NOI /NOE /NOLOGO /ALIGN:4 /EXEPACK:2 $(EXTRALINK)

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

objssqldll = hashdll.obj rxpackdll.obj rxsqldll.obj
objssqlexe = getopt.obj hashexe.obj rxpackexe.obj rxsqlexe.obj loader.obj
objsdbdll = hashdll.obj rxpack$(db)dll.obj rx$(db)dll.obj
objsdbexe = getopt.obj hashexe.obj rxpack$(db)exe.obj rx$(db)exe.obj loader$(db).obj

ccsqldll = icc $(cflagsdll) $(listopt)
ccsqlexe = icc $(cflagsexe) $(listopt)
ccdbdll = icc $(cflagsdll) $(listopt) $(DBDEFINE)
ccdbexe = icc $(cflagsexe) $(listopt) $(DBDEFINE)

H1=$(SRC)\general\rexxsql.h
H2=$(DBDIR)\dbdefine.h
H3=$(DBDIR)\dbheader.h
H4=$(DBDIR)\dbtypes.h
H5=$(SRC)\general\hash.h $(SRC)\general\rxsqlinc1.h $(SRC)\general\rxsqlinc2.h

all: rexxsql.dll rexxsql.exe rexx$(db).dll rexx$(db).exe dist

#
# These function only required for EXE
#
getopt.obj: $(SRC)\common\getopt.c
    $(ccsqlexe) /Fogetopt.obj $(SRC)\common\getopt.c

loader.obj: $(SRC)\common\loader.c $(H1) $(H2)
    $(ccsqlexe) /Foloader.obj $(SRC)\common\loader.c

loader$(db).obj: $(SRC)\common\loader.c $(H1) $(H2)
    $(ccdbexe) /Foloader$(db).obj $(SRC)\common\loader.c

#
# These functions required for both EXE and DLL
# Same file used for standard and DB-specific binary
#
hashdll.obj: $(SRC)\general\hash.c $(H5)
    $(ccsqldll) /Fohashdll.obj $(SRC)\general\hash.c

hashexe.obj: $(SRC)\general\hash.c $(H5)
    $(ccsqlexe) /Fohashexe.obj $(SRC)\general\hash.c
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

rxpackdll.obj: $(SRC)\common\rxpack.c $(H5)
    $(ccsqldll) /Forxpackdll.obj $(SRC)\common\rxpack.c

rxpackexe.obj: $(SRC)\common\rxpack.c $(H5)
    $(ccsqlexe) /Forxpackexe.obj $(SRC)\common\rxpack.c

rxpack$(db)dll.obj: $(SRC)\common\rxpack.c $(H5)
    $(ccdbdll) /Forxpack$(db)dll.obj $(SRC)\common\rxpack.c

rxpack$(db)exe.obj: $(SRC)\common\rxpack.c $(H5)
    $(ccdbexe) /Forxpack$(db)exe.obj $(SRC)\common\rxpack.c


rexxsql.dll: $(objssqldll) rexxsqldll.def
	-7 ilink $(lflagsdll) rxpackdll.obj+hashdll.obj+rxsqldll.obj,$@,$*.map,$(DBLIBS),rexxsqldll.def;
	rc $(SRC)\rexxsql_os2.res rexxsql.dll

rexxsql.exe: $(objssqlexe) rexxsqlexe.def
	-7 ilink $(lflagsexe) loader.obj+rxpackexe.obj+hashexe.obj+rxsqlexe.obj+getopt.obj,$@,$*.map,$(DBLIBS),rexxsqlexe.def;
	rc $(SRC)\rexxsql_os2.res rexxsql.exe

rexx$(db).dll: $(objsdbdll) rexx$(db)dll.def
	-7 ilink $(lflagsdll) rxpack$(db)dll.obj+hashdll.obj+rx$(db)dll.obj,$@,$*.map,$(DBLIBS),rexx$(db)dll.def;
	rc $(SRC)\rexxsql_os2.res rexx$(db).dll

rexx$(db).exe: $(objsdbexe) rexx$(db)exe.def
	-7 ilink $(lflagsexe) loader$(db).obj rxpack$(db)exe.obj+rx$(db)exe.obj+hashexe.obj+getopt.obj,$@,$*.map,$(DBLIBS),rexx$(db)exe.def;
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

#
# Rules for DEF files
#
rexxsqldll.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx SQL DLL OS2 rexxsqldll.def

rexxsqlexe.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx SQL EXE OS2 rexxsqlexe.def

rexx$(db)dll.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx $(DB) DLL OS2 rexx$(db)dll.def

rexx$(db)exe.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx $(DB) EXE OS2 rexx$(db)exe.def
