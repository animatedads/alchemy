#
# NMAKE-compatible MAKE file for building REXX/SQL with VC++
#
# will generate:
#
#      rexxsql.dll
#      rexxsql.exe
#      rexx<db>.dll
#      rexx<db>.exe
#
# Usage: nmake [DEBUG=1]
#              [INT=REGINA|OREXX|OOREXX|OOREXX4|WINREXX|QUERCUS|REXXTRANS]
#              [DB=SAW|ODBC|UDBC|ORA7|ORA|MIN|DB2|SYB|MIN2|SOL|MY|VEL|LITE]
#              [SOLLIB=???]
#              [rexxsql.dll|rexxsql.exe|rexx<db>.dll|rexx<db>.exe]
#

PROJ = rexxsql
SRC = $(REXXSQL_SRCDIR)
DISTDIR=$(SRC)

!include $(SRC)\rexxsql.ver
VERDOT = $(VER_DOT)
VERDATE = $(VER_DATE)

ORA7_DBLIBS = $(ORA_HOMEDIR)\lib\msvc\ociw32.lib
ORA7_DBINC =
ORA_DBLIBS = $(ORA_HOMEDIR)\lib\msvc\oci.lib
ORA_DBINC = -I$(ORA_HOMEDIR)\include
DB2_DBLIBS = $(DB2_HOMEDIR)\lib\db2cli.lib
DB2_DBINC = -I$(DB2_HOMEDIR)\include
SAW_DBLIBS = $(SAW_HOMEDIR)\win32\lib\odbc32.lib
SAW_DBINC = -I$(SAW_HOMEDIR)\h #/If:\sqlany50\h
MIN2_DBLIBS = $(MIN2_HOMEDIR)\lib\msql_dll.lib wsock32.lib advapi32.lib
MIN2_DBINC = -I$(MIN2_HOMEDIR)\include
MIN_DBLIBS = $(MIN_HOMEDIR)\lib\msql_dll.lib wsock32.lib advapi32.lib
MIN_DBINC = -I$(MIN_HOMEDIR)\include
ODBC_DBLIBS = odbc32.lib #$(ODBC_HOMEDIR)\odbc32.lib
ODBC_DBINC = #-I$(ODBC_HOMEDIR)
UDBC_DBLIBS = $(UDBC_HOMEDIR)\lib\librpc.lib $(UDBC_HOMEDIR)\lib\opludb32.lib wsock32.lib
UDBC_DBINC = -I$(UDBC_HOMEDIR)\include /MT
#SOL_DBLIBS = $(SOL_HOMEDIR)\lib\SCLW3223.LIB
SOL_DBLIBS = $(SOL_HOMEDIR)\lib\$(SOLLIB)
SOL_DBINC = -I$(SOL_HOMEDIR)\include /DSS_NT /DSOLID_SERVER /DSS_EE
LITE_DBLIBS = $(SQLITE3_HOMEDIR)\lib\sqlite3.lib
LITE_DBINC = -I$(SQLITE3_HOMEDIR)\include

!if "$(DEBUG)" == "Y"
MY_DBLIBS = wsock32.lib advapi32.lib #$(MY_HOMEDIR)\lib\debug\mysqlclient.lib
MY_DBINC = -I$(MY_HOMEDIR)\include #/MTd
!else
MY_DBLIBS =  wsock32.lib advapi32.lib #$(MY_HOMEDIR)\lib\opt\mysqlclient.lib
MY_DBINC = -I$(MY_HOMEDIR)\include #/MT
!endif

VEL_DBLIBS = $(VEL_HOMEDIR)\lib\rdscli.lib wsock32.lib advapi32.lib
VEL_DBINC = -I$(VEL_HOMEDIR)\include /MD /DNT_INTEL /DWIN32_NT /DNT /DMSC /DVELOCIS

REGINA_REXXLIBS = $(REGINA_BINDIR)\regina.lib
#REGINA_REXXINC = -DUSE_REGINA # temporarily disable regina directory
REGINA_REXXINC = -I$(REGINA_SRCDIR) -DUSE_REGINA
OREXX_REXXLIBS = $(OREXX_BINDIR)\api\rexx.lib $(OREXX_BINDIR)\api\rexxapi.lib
OREXX_REXXINC = -I$(OREXX_BINDIR)\api -DUSE_OREXX
OOREXX_REXXLIBS = "$(REXX_HOME)\api\rexx.lib" "$(REXX_HOME)\api\rexxapi.lib"
OOREXX_REXXINC = -I"$(REXX_HOME)\api" -DUSE_OOREXX
OOREXX4_REXXLIBS = "$(REXX_HOME)\api\rexx.lib" "$(REXX_HOME)\api\rexxapi.lib"
OOREXX4_REXXINC = -I"$(REXX_HOME)\api" -DUSE_OOREXX -DOOREXX_40
WINREXX_REXXLIBS = f:\winrexx\api\rxrexx.lib
WINREXX_REXXINC = -If:\winrexx\api -DUSE_WINREXX
QUERCUS_REXXLIBS = f:\quercus\wrexx32.lib
QUERCUS_REXXINC = -If:\quercus -DUSE_QUERCUS
UNIREXX_REXXLIBS = f:\unirexx\api\rx.lib
UNIREXX_REXXINC = -If:\unirexx\api -DUSE_UNIREXX
REXXTRANS_REXXLIBS = $(REXXTRANS_BINDIR)\rexxtrans.lib
REXXTRANS_REXXINC = -I$(REXXTRANS_SRCDIR) -DUSE_REXXTRANS
#---------------------------------------------------------------------
# You should not have to change anything below here...
#---------------------------------------------------------------------

#
# Database specific defines
#
!if "$(DB)" == "ORA7"
LDB = ora7
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(DBDIR)
CLI=ora7
DBLIBS = $(ORA7_DBLIBS)
DBINC = $(ORA7_DBINC)
DBDEFINE = /DORA7_PREFIX

!elseif "$(DB)" == "ORA"
LDB = ora
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(DBDIR)
CLI=ora
DBLIBS = $(ORA_DBLIBS)
DBINC = $(ORA_DBINC)
DBDEFINE = /DORA_PREFIX

!elseif "$(DB)" == "DB2"
LDB = db2
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(DB2_DBLIBS)
DBINC = $(DB2_DBINC)
DBDEFINE = /DDB2_PREFIX

!elseif "$(DB)" == "SAW"
LDB = saw
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(SAW_DBLIBS)
DBINC = $(SAW_DBINC)
DBDEFINE = /DSAW_PREFIX

!elseif "$(DB)" == "VEL"
LDB = vel
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(VEL_DBLIBS)
DBINC = $(VEL_DBINC)
DBDEFINE = /DVEL_PREFIX

!elseif "$(DB)" == "MIN"
LDB = min
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(DBDIR)
CLI=min
DBLIBS = $(MIN_DBLIBS)
DBINC =  $(MIN_DBINC)
DBDEFINE = /DMIN_PREFIX

!elseif "$(DB)" == "MIN2"
LDB = min
DBDIR=$(SRC)\min2
CLIDIR=$(DBDIR)
CLI=min
DBLIBS = $(MIN2_DBLIBS)
DBINC =  $(MIN2_DBINC)
DBDEFINE = /DMIN_PREFIX

!elseif "$(DB)" == "MY"
LDB = my
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(DBDIR)
CLI=my
DBLIBS = $(MY_DBLIBS)
DBINC =  $(MY_DBINC) /DREQUIRE_MY_GLOBAL_H
DBDEFINE = /DMY_PREFIX

!elseif "$(DB)" == "ODBC"
LDB = odbc
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(ODBC_DBLIBS)
DBINC =  $(ODBC_DBINC)
DBDEFINE = /DODBC_PREFIX

!elseif "$(DB)" == "UDBC"
LDB = udbc
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(UDBC_DBLIBS)
DBINC =  $(UDBC_DBINC)
DBDEFINE = /DUDBC_PREFIX

!elseif "$(DB)" == "SOL"
LDB = sol
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = $(SOL_DBLIBS)
DBINC =  $(SOL_DBINC)
DBDEFINE = /DSOL_PREFIX

!elseif "$(DB)" == "LITE"
LDB = lite
DBDIR=$(SRC)\sqlite3
CLIDIR=$(DBDIR)
CLI=sqlite3
DBLIBS = $(LITE_DBLIBS)
DBINC =  $(LITE_DBINC)
DBDEFINE = /DLITE_PREFIX

!elseif "$(DB)" == "SYB"
DBDEFINE = /DSYB_PREFIX
!else
!message Target Database NOT specified via DB macro
!message Valid values are: ORA7 ORA SAW ODBC MIN DB2 SYB SOL MY MIN2 LITE
!error Make aborted!
!endif

#
# Interpreter specific defines
#
!if "$(INT)" == "REGINA"
REXXLIBS = $(REGINA_REXXLIBS)
REXXINC =  $(REGINA_REXXINC)
!elseif "$(INT)" == "OREXX"
REXXLIBS = $(OREXX_REXXLIBS)
REXXINC =  $(OREXX_REXXINC)
!elseif "$(INT)" == "OOREXX4"
REXXLIBS = $(OOREXX4_REXXLIBS)
REXXINC =  $(OOREXX4_REXXINC)
!elseif "$(INT)" == "OOREXX"
REXXLIBS = $(OOREXX_REXXLIBS)
REXXINC =  $(OOREXX_REXXINC)
!elseif "$(INT)" == "WINREXX"
REXXLIBS = $(WINREXX_REXXLIBS)
REXXINC =  $(WINREXX_REXXINC)
!elseif "$(INT)" == "QUERCUS"
REXXLIBS = $(QUERCUS_REXXLIBS)
REXXINC =  $(QUERCUS_REXXINC)
!elseif "$(INT)" == "UNIREXX"
REXXLIBS = $(UNIREXX_REXXLIBS)
REXXINC =  $(UNIREXX_REXXINC)
!elseif "$(INT)" == "REXXTRANS"
REXXLIBS = $(REXXTRANS_REXXLIBS)
REXXINC =  $(REXXTRANS_REXXINC)
distro = dist
!else
!message Rexx Interpreter NOT specified via INT macro
!message Valid values are: REGINA OREXX OOREXX OOREXX4 WINREXX QUERCUS UNIREXX REXXTRANS
!error Make aborted!
!endif

INCCOMDIR = $(SRC)\common
INCGENDIR = $(SRC)\general
INCDBDIR = $(DBDIR)
INCSRCDIR = $(CLIDIR)
CC20 = -o $@
MYLDEXTRA = emxbind

EXTRALINK =
CCLIBS = user32.lib
CC = cl
LINK = link
GETOPT = getopt.obj
CC2O = /Fo$@

comcopts = -nologo -W3 -c -DWIN64 -DHAVE_PROTO -I$(DBDIR) -I$(SRC)\common -I$(SRC)\general $(DBINC) $(REXXINC) -DREXXSQL_VERSION=\"$(VERDOT)\" -DREXXSQL_DATE=\"$(VERDATE)\"
comlopts = -nologo -machine:X64 $(EXTRALINK) #/NOI /NOE /NOLOGO /EXEPACK:2 /ALIGN:4 $(EXTRALINK)

!if "$(DEBUG)" == "Y"
copts  = $(comcopts) -Od -Z7 -FR -DDEBUG
lopts  = $(comlopts) -debug -pdb:none #-debugtype:coff -fixed:no #-pdb:none
!else
copts  = $(comcopts) -Ox
lopts  = $(comlopts) -release
DEBUG = N
!endif

dbcflags  = -DINIT_RXPACKAGE=init_Rexx$(DB) -DTERM_RXPACKAGE=term_Rexx$(DB)
sqlcflags = -DINIT_RXPACKAGE=init_RexxSQL   -DTERM_RXPACKAGE=term_RexxSQL

cflagsdll = $(copts) -DDYNAMIC -MT -LD
cflagsexe = $(copts) -MT
lflagsdll = $(lopts) -dll -implib:$(*B).lib
lflagsexe = $(lopts)

SSQLOBJS = $(GETOPT) loader.obj $(CLI).obj rxpack.obj exe_res.obj rxmt_win64.obj
SDBOBJS = $(GETOPT) loader_$(LDB).obj $(CLI)_$(LDB).obj rxpack.obj exe_$(LDB)_res.obj rxmt_win64_$(LDB).obj
DSQLOBJS = $(CLI)_dyn.obj rxpack_dyn.obj dll_res.obj rxmt_win64_dyn.obj
DDBOBJS = $(CLI)_$(LDB)_dyn.obj rxpack_dyn.obj dll_$(LDB)_res.obj rxmt_win64_$(LDB)_dyn.obj

ccsqldll = $(CC) $(cflagsdll) $(listopt)
ccsqlexe = $(CC) $(cflagsexe) $(listopt)
ccdbdll = $(CC) $(cflagsdll) $(listopt) $(DBDEFINE)
ccdbexe = $(CC) $(cflagsexe) $(listopt) $(DBDEFINE)

H1=$(INCGENDIR)\rexxsql.h $(INCCOMDIR)\defines.h
H2=$(INCDBDIR)\dbdefine.h $(INCDBDIR)\dbheader.h $(INCDBDIR)\dbtypes.h
H3=$(INCGENDIR)\rxsqlinc1.h $(INCGENDIR)\rxsqlinc2.h
H4=#$(INCGENDIR)\hash.h
H5=$(INCCOMDIR)\rxpack.h $(INCCOMDIR)\rxdef.h
H6=$(INCCOMDIR)\rxmt_win64.h $(INCCOMDIR)\rxmt.h
H7=$(INCCOMDIR)\rxmt_notmt.h $(INCCOMDIR)\rxmt.h

all: how rexxsql.exe rexxsql.dll rexx$(LDB).dll rexx$(LDB).exe $(distro)

how:
	echo nmake -f $(SRC)\vcwin64.mak INT=$(INT) DB=$(DB) DEBUG=$(DEBUG) %%%1 %%%2 > rebuild.bat
#
# Rules for executables and DLLs
#
rexxsql.exe: $(SSQLOBJS) $(GETOPT)
	link $(lflagsexe) $(SSQLOBJS) -out:rexxsql.exe $(DBLIBS) $(CCLIBS) $(REXXLIBS)

rexx$(LDB).exe: $(SDBOBJS) $(GETOPT)
	link $(lflagsexe) $(SDBOBJS) -out:rexx$(LDB).exe $(DBLIBS) $(CCLIBS) $(REXXLIBS)

rexxsql.dll: $(DSQLOBJS) rexxsql.def
	link $(lflagsdll) $(DSQLOBJS) -out:rexxsql.dll $(DBLIBS) $(CCLIBS) $(REXXLIBS) -def:rexxsql.def

rexx$(LDB).dll: $(DDBOBJS) rexx$(LDB).def
	link $(lflagsdll) $(DDBOBJS) -out:rexx$(LDB).dll $(DBLIBS) $(CCLIBS) $(REXXLIBS) -def:rexx$(LDB).def


getopt.obj: $(INCCOMDIR)\getopt.c $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(INCCOMDIR)\getopt.c

rxpack.obj: $(INCCOMDIR)\rxpack.c $(H5) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(sqlcflags) $(CC2O) $(INCCOMDIR)\rxpack.c

rxpack_dyn.obj: $(INCCOMDIR)\rxpack.c $(H5) $(SRC)\rexxsql.ver
	$(ccsqldll) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxpack.c

rxmt_win64.obj: $(INCCOMDIR)\rxmt_win64.c $(H6) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_win64.c

rxmt_win64_dyn.obj: $(INCCOMDIR)\rxmt_win64.c $(H6) $(SRC)\rexxsql.ver
	$(ccsqldll) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_win64.c

rxmt_win64_$(LDB)_dyn.obj: $(INCCOMDIR)\rxmt_win64.c $(H6) $(SRC)\rexxsql.ver
	$(ccsqldll) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_win64.c

rxmt_win64_$(LDB).obj: $(INCCOMDIR)\rxmt_win64.c $(H6) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_win64.c

rxmt_notmt.obj: $(INCCOMDIR)\rxmt_notmt.c $(H7) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_notmt.c

rxmt_notmt_$(LDB).obj: $(INCCOMDIR)\rxmt_notmt.c $(H7) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_notmt.c

loader.obj: $(INCCOMDIR)\loader.c $(H1) $(H2) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\loader.c

loader_$(LDB).obj: $(INCCOMDIR)\loader.c $(H1) $(H2) $(SRC)\rexxsql.ver
	$(ccdbexe) $(CC2O) $(dbcflags) $(INCCOMDIR)\loader.c

rexxsql_dyn.obj: $(INCGENDIR)\rexxsql.c $(H1) $(H2)  $(SRC)\rexxsql.ver
	$(ccsqldll) $(CC2O) $(sqlcflags) $(INCGENDIR)\rexxsql.c

rexxsql_$(LDB)_dyn.obj: $(INCGENDIR)\rexxsql.c $(H1) $(H2) $(SRC)\rexxsql.ver
	$(ccdbdll) $(CC2O) $(dbcflags) $(INCGENDIR)\rexxsql.c

$(CLI).obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3) $(SRC)\rexxsql.ver
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_$(LDB).obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3) $(SRC)\rexxsql.ver
	$(ccdbexe) $(CC2O) $(dbcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_dyn.obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3) $(SRC)\rexxsql.ver
	$(ccsqldll) $(CC2O) $(sqlcflags) $(INCSRCDIR)\$(CLI).c

$(CLI)_$(LDB)_dyn.obj: $(INCSRCDIR)\$(CLI).c $(H1) $(H2) $(H3) $(SRC)\rexxsql.ver
	$(ccdbdll) $(CC2O) $(dbcflags) $(INCSRCDIR)\$(CLI).c


#
# Rules for resources
#
.\$(PROJ)_w64.rc : $(SRC)\rexxsql.ver $(SRC)\$(PROJ)_w64.rc
	rexx $(INCCOMDIR)\fixrc.rexx $(SRC)\$(PROJ)_w64.rc .\$(PROJ)_w64.rc  $(VERDOT) $(VERDATE)

exe_res.obj exe_res.res: .\$(PROJ)_w64.rc $(SRC)\rexxsql.ver
	copy $(SRC)\rexxsql_w64.ico .
	rc /r /foexe_res.res /D$(INT) /DNODB /D$(DB) /i$(SRC) .\$(PROJ)_w64.rc
	cvtres /MACHINE:X64 /NOLOGO /OUT:exe_res.obj exe_res.res

dll_res.obj dll_res.res: .\$(PROJ)_w64.rc $(SRC)\rexxsql.ver
	copy $(SRC)\rexxsql_w64.ico .
	rc /r /fodll_res.res /DYNAMIC /D$(INT) /DNODB /D$(DB) /i$(SRC) .\$(PROJ)_w64.rc
	cvtres /MACHINE:X64 /NOLOGO /OUT:dll_res.obj dll_res.res

exe_$(LDB)_res.obj exe_$(LDB)_res.res: .\$(PROJ)_w64.rc $(SRC)\rexxsql.ver
	copy $(SRC)\rexxsql_w64.ico .
	rc /r /foexe_$(LDB)_res.res /D$(INT) /D$(DB) /i$(SRC) .\$(PROJ)_w64.rc
	cvtres /MACHINE:X64 /NOLOGO /OUT:exe_$(LDB)_res.obj exe_$(LDB)_res.res

dll_$(LDB)_res.obj dll_$(LDB)_res.res: .\$(PROJ)_w64.rc $(SRC)\rexxsql.ver
	copy $(SRC)\rexxsql_w64.ico .
	rc /r /fodll_$(LDB)_res.res /DDYNAMIC /D$(INT) /D$(DB) /i$(SRC) .\$(PROJ)_w64.rc
	cvtres /MACHINE:X64 /NOLOGO /OUT:dll_$(LDB)_res.obj dll_$(LDB)_res.res

#
# Rules for DEF files
#
rexxsql.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx SQL DLL W64 rexxsql.def $(DB)

rexx$(LDB).def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx $(DB) DLL W64 rexx$(LDB).def $(DB)

#
# Rules for distribution
#
dist:
	regina $(SRC)\dist\makedist w64 $(LDB) $(VERDOT)
