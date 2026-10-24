#
# GNU MAKE-compatible MAKE file for building REXX/SQL with EMX 0.9d
#
# will generate:
#
#      rexxsql.dll
#      rexxsql.exe
#      rexx<db>.dll
#      rexx<db>.exe
#
# Usage: nmake [DEBUG=Y]
#              [DB=SAW|ODBC|UDBC|ORA|MIN|DB2|SYB|MIN2|SOL|MY|MY4|LITE]
#              [INT=REGINA|OS2REXX|REXXTRANS]
#              [rexxsql.dll|rexxsql.exe|rexx<db>.dll|rexx<db>.exe]
#

SRC = $(REXXSQL_SRCDIR)
include $(SRC)\rexxsql.ver

#---------------------------------------------------------------------
# You should not have to change anything below here...
#---------------------------------------------------------------------


MYLDEXTRA = emxbind
OBJ=o
#
# Database specific defines
#
BDB = $(DB)
ifeq ($(DB),ORA)
LDB = ora
DBDEFINE = -DORA_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=ora
DBLIBS = ora7o32
EXTRAINC =

else
ifeq ($(DB),DB2)
LDB = db2
DBDEFINE = -DDB2_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
OBJ=obj
DBLIBSEXE = -lc:\sqllib\lib\db2cli.lib #-Zomf
DBLIBSDLL = $(DBLIBSEXE)
EXTRAINC = -Zomf -Ic:\sqllib\include
MYLDEXTRA = echo

else
ifeq ($(DB),SAW)
LDB = saw
DBDEFINE = -DSAW_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
OBJ=obj
DBLIBSEXE = -Zomf -lc:\sqlany50\os2\lib\wodbc2
DBLIBSDLL = $(DBLIBSEXE)
EXTRAINC = -Zomf -Ic:\sqlany50\h
MYLDEXTRA = echo

else
ifeq ($(DB),MIN)
db = min
DBDEFINE = -DMIN_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\$(DB)
CLI=min
DBLIBS = rexx+c:\public\msql\lib\msql_dll.lib+c:\tcpip\lib\so32dll.lib+c:\tcpip\lib\tcp32dll.lib
EXTRAINC = -Ic:\public\msql\include

else
ifeq ($(DB),MY)
LDB = my
DBDEFINE = -DMY_PREFIX
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\$(LDB)
CLI=my
OBJ=obj
DBLIBSEXE = -L$(MY_HOMEDIR)\lib -llibmysqlclient
DBLIBSDLL = $(DBLIBSEXE)
EXTRAINC = -I$(MY_HOMEDIR)\include\mysql -DHAVE_GETOPT
MYLDEXTRA = echo
GETOPT=getopt.$(OBJ)
EXTRALINK =  -Zcrtdll=pthrdrtl

else
ifeq ($(DB),MY4)
LDB = my
DB = MY
DBDEFINE = -DMY_PREFIX
DBDIR=$(SRC)\$(LDB)
CLIDIR=$(SRC)\$(LDB)
CLI=my
OBJ=obj
DBLIBSEXE = -L$(MY_HOMEDIR)\lib -lmysqlclient
DBLIBSDLL = $(DBLIBSEXE)
EXTRAINC = -I$(MY_HOMEDIR)\include -DHAVE_GETOPT
MYLDEXTRA = echo
GETOPT=getopt.$(OBJ)

else
ifeq ($(DB),MIN2)
LDB = min
DBDEFINE = -DMIN_PREFIX
DBDIR=$(SRC)\min2
CLIDIR=$(SRC)\min2
CLI=min
DBLIBSEXE = -Lc:\public\msql2\lib -llibmsql
DBLIBSDLL = -Lc:\public\msql2\lib -lmsql
EXTRAINC = -Ic:\public\msql2\include

else
ifeq ($(DB),LITE)
LDB = lite
DBDEFINE = -DLITE_PREFIX
DBDIR=$(SRC)\sqlite3
CLIDIR=$(DBDIR)
CLI=sqlite3
DBLIBSEXE = $(SQLITE3_HOMEDIR)\lib\sqlite3.a
DBLIBSDLL = $(SQLITE3_HOMEDIR)\lib\sqlite3.a
EXTRAINC = -I$(SQLITE3_HOMEDIR)\include
MYLDEXTRA = echo
EXTRALINK = #-Zcrtdll

else
ifeq ($(DB),ODBC)
error Use vacos2.mak
LDB = odbc
DBDEFINE = -DODBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
OBJ=obj
DBLIBSEXE = \os2\lib\odbc.lib
DBLIBSDLL = $(DBLIBSEXE)
EXTRAINC = -I\os2\include -DHAVE_GETOPT
MYLDEXTRA = echo
GETOPT=getopt.$(OBJ)

else
ifeq ($(DB),UDBC)
db = udbc
DBDEFINE = -DUDBC_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+h:\udbc\lib\opludbc.lib
EXTRAINC = -Ih:\udbc\include

else
ifeq ($(DB),SYB)
db = syb
DBDEFINE = -DSYB_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(DBDIR)
CLI=syb
DBLIBS = rexx+e:\sql10\lib\libct+e:\sql10\lib\libcs
EXTRAINC = -Ie:\sql10\include
else
ifeq ($(DB),SOL)
db = sol
DBDEFINE = -DSOL_PREFIX
DBDIR=$(SRC)\$(DB)
CLIDIR=$(SRC)\cli-odbc
CLI=rexxcli
DBLIBS = rexx+h:\ss\lib\SCLO3222.LIB
EXTRAINC = -Ih:\ss\include -DSOLID_SERVER
else
error Target Database NOT specified via DB macro. Valid values are: ORA SAW ODBC MIN MIN2 DB2 SYB SOL
endif
endif
endif
endif
endif
endif
endif
endif
endif
endif
endif
endif

ifeq ($(INT),REGINA)
REXXLIBSEXE = $(REGINA_BINDIR)\regina.lib
REXXLIBSDLL = $(REGINA_BINDIR)\regina.lib
REXXINC = -I$(REGINA_SRCDIR) -DUSE_REGINA

else
ifeq ($(INT),REXXTRANS)
REXXLIBSEXE = $(REXXTRANS_BINDIR)\rexxtrans.lib
REXXLIBSDLL = $(REXXLIBSEXE)
REXXINC = -I$(REXXTRANS_SRCDIR) -DUSE_REXXTRANS

else
REXXLIBSEXE =
REXXLIBSDLL =
REXXINC = -DUSE_OS2REXX
endif
endif

INCCOMDIR = $(SRC)\common
INCGENDIR = $(SRC)\general
INCDBDIR = $(DBDIR)
CC2O = -o $@

DISTDIR=$(SRC)\dist\$(DB)
CC = gcc
LINK = gcc

comcopts = -Zomf -DRXPACK_MULTI -DOS2 -D__OS2__ -DSTDC_HEADERS -DHAVE_PROTO -I$(INCDBDIR) -I$(SRC) -I$(INCCOMDIR) -I$(INCGENDIR) $(EXTRAINC)  $(REXXINC) -DREXXSQL_DATE=\"$(VER_DATE)\" -DREXXSQL_VERSION=\"$(VER_DOT)\"
comlopts = $(EXTRALINK) -Zomf -s #-Zmt

ifeq ($(DEBUG),Y)
copts     = -c -g -Wall $(comcopts) -DDEBUG
lopts     = -g $(comlopts)
else
copts     = -c -O3 -Wall $(comcopts)
lopts     = -O3 $(comlopts)
DEBUG     = N
endif

dbcflags  = -DINIT_RXPACKAGE=init_Rexx$(DB) -DTERM_RXPACKAGE=term_Rexx$(DB)
sqlcflags = -DINIT_RXPACKAGE=init_RexxSQL   -DTERM_RXPACKAGE=term_RexxSQL

cflagsdll = $(copts) -DDYNAMIC -Zdll -Zmt
cflagsexe = $(copts) -Zmt
lflagsdll = $(lopts) -Zdll -Zmt -Zcrtdll
lflagsexe = $(lopts) -Zmt

SSQLOBJS = loader.$(OBJ) $(CLI).$(OBJ) rxpack.$(OBJ) $(GETOPT) rxmt_os2.obj
SDBOBJS = loader_$(LDB).$(OBJ) $(CLI)_$(LDB).$(OBJ) rxpack_$(LDB).$(OBJ) $(GETOPT) rxmt_os2_$(LDB).obj
DSQLOBJS = $(CLI)_dyn.$(OBJ) rxpack_dyn.$(OBJ) rxmt_os2_dyn.obj
DDBOBJS = $(CLI)_$(LDB)_dyn.$(OBJ) rxpack_$(LDB)_dyn.$(OBJ) rxmt_os2_$(LDB)_dyn.obj

ccsqldll = gcc $(cflagsdll) $(listopt)
ccsqlexe = gcc $(cflagsexe) $(listopt)
ccdbdll = gcc $(cflagsdll) $(listopt) $(DBDEFINE)
ccdbexe = gcc $(cflagsexe) $(listopt) $(DBDEFINE)

H1=$(INCGENDIR)\rexxsql.h $(INCCOMDIR)\defines.h $(INCGENDIR)\apphead.h
H2=$(INCDBDIR)\dbdefine.h $(INCDBDIR)\dbheader.h $(INCDBDIR)\dbtypes.h
#H3=$(INCGENDIR)\common.h
#H4=$(INCGENDIR)\hash.h
H5=$(INCCOMDIR)\rxpack.h $(INCCOMDIR)\rxdef.h
H6=$(INCCOMDIR)\rxmt_os2.h $(INCCOMDIR)\rxmt.h
H7=$(INCCOMDIR)\rxmt_notmt.h $(INCCOMDIR)\rxmt.h

all: how rexxsql.exe rexxsql.dll rexx$(LDB).exe rexx$(LDB).dll

how:
	echo make -f $(SRC)\gccos2.mak INT=$(INT) DB=$(DB) DEBUG=$(DEBUG) ^%1 ^%2 > rebuild.cmd

rexxsql.exe: $(SSQLOBJS) $(GETOPT)
	$(LINK) $(lflagsexe) -o rexxsql $(SSQLOBJS) $(DBLIBSEXE) $(REXXLIBSEXE)
	$(MYLDEXTRA) rexxsql
	-copy $(SRC)\rexxsql_os2.ico .\rexxsql.ico
	-copy $(SRC)\rexxsql_os2.rc .
	rc rexxsql_os2.rc $@

rexx$(LDB).exe: $(SDBOBJS)
	$(LINK) $(lflagsexe) -o rexx$(LDB) $(SDBOBJS) $(DBLIBSEXE) $(REXXLIBSEXE)
	$(MYLDEXTRA) rexx$(LDB)
	-copy $(SRC)\rexxsql_os2.ico .\rexxsql.ico
	-copy $(SRC)\rexxsql_os2.rc .
	rc rexxsql_os2.rc $@

rexxsql.dll: $(DSQLOBJS) rexxsqldll.def
	$(LINK) $(lflagsdll) -o $@ $(DSQLOBJS) $(DBLIBSDLL) $(REXXLIBSDLL) rexxsqldll.def
	-copy $(SRC)\rexxsql_os2.ico .\rexxsql.ico
	-copy $(SRC)\rexxsql_os2.rc .
	rc rexxsql_os2.rc $@

rexx$(LDB).dll: $(DDBOBJS) $(RXPACKEXP2) rexx$(LDB)dll.def
	$(LINK) $(lflagsdll) -o $@ $(DDBOBJS) $(DBLIBSDLL) $(REXXLIBSDLL) rexx$(LDB)dll.def
	-copy $(SRC)\rexxsql_os2.ico .\rexxsql.ico
	-copy $(SRC)\rexxsql_os2.rc .
	rc rexxsql_os2.rc $@

rxpack.$(OBJ): $(INCCOMDIR)\rxpack.c $(H5)
	$(CC) $(cflagsexe) $(CC2O) $(INCCOMDIR)\rxpack.c

rxpack_dyn.$(OBJ): $(INCCOMDIR)\rxpack.c $(H5)
	$(CC) $(cflagsdll) $(CC2O) $(INCCOMDIR)\rxpack.c

rxpack_$(LDB).$(OBJ): $(INCCOMDIR)\rxpack.c $(H5)
	$(CC) $(cflagsexe) $(DBDEFINE) $(CC2O) $(INCCOMDIR)\rxpack.c

rxpack_$(LDB)_dyn.$(OBJ): $(INCCOMDIR)\rxpack.c $(H5)
	$(CC) $(cflagsdll) $(DBDEFINE) $(CC2O) $(INCCOMDIR)\rxpack.c

rxmt_os2.obj: $(INCCOMDIR)\rxmt_os2.c $(H6)
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_os2.c

rxmt_os2_dyn.obj: $(INCCOMDIR)\rxmt_os2.c $(H6)
	$(ccsqldll) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_os2.c

rxmt_os2_$(LDB)_dyn.obj: $(INCCOMDIR)\rxmt_os2.c $(H6)
	$(ccsqldll) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_os2.c

rxmt_os2_$(LDB).obj: $(INCCOMDIR)\rxmt_os2.c $(H6)
	$(ccsqlexe) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_os2.c

rxmt_notmt.obj: $(INCCOMDIR)\rxmt_notmt.c $(H7)
	$(ccsqlexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\rxmt_notmt.c

rxmt_notmt_$(LDB).obj: $(INCCOMDIR)\rxmt_notmt.c $(H7)
	$(ccsqlexe) $(CC2O) $(dbcflags) $(INCCOMDIR)\rxmt_notmt.c

loader.$(OBJ): $(INCCOMDIR)\loader.c $(H1) $(H2)
	$(CC) $(cflagsexe) $(CC2O) $(sqlcflags) $(INCCOMDIR)\loader.c

loader_$(LDB).$(OBJ): $(INCCOMDIR)\loader.c $(H1) $(H2)
	$(CC) $(cflagsexe) $(DBDEFINE) $(CC2O) $(dbcflags) $(INCCOMDIR)\loader.c

$(CLI).$(OBJ): $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(CC) $(cflagsexe) $(CC2O) $(sqlcflags) $(CLIDIR)\$(CLI).c

$(CLI)_$(LDB).$(OBJ): $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(CC) $(cflagsexe) $(DBDEFINE) $(CC2O) $(dbcflags) $(CLIDIR)\$(CLI).c

$(CLI)_dyn.$(OBJ): $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(CC) $(cflagsdll) $(CC2O) $(sqlcflags) $(CLIDIR)\$(CLI).c

$(CLI)_$(LDB)_dyn.$(OBJ): $(CLIDIR)\$(CLI).c $(H1) $(H2) $(H3)
	$(CC) $(cflagsdll) $(DBDEFINE) $(CC2O) $(dbcflags) $(CLIDIR)\$(CLI).c


getopt.$(OBJ): $(INCCOMDIR)\getopt.c
	$(CC) $(cflagsexe) $(CC2O) $(INCCOMDIR)\getopt.c


#rexxsql.dll: $(objssqldll)
#	link386 $(lflagsdll) utsqldll.o+hashdll.o+rxsqldll.o,$@,$*.map,$(DBLIBS),$(SRC)\rexxsql_os2_dll.def;
#	rc $(SRC)\rexxsql_os2.res rexxsql.dll

#rexxsql.exe: $(objssqlexe)
#	link386 $(lflagsexe) utsqlexe.o+rxsql.o+hashexe.o+rxsqlexe.o+getopt.o,$@,$*.map,$(DBLIBS),$(SRC)\rexxsql_os2_exe.def;
#	rc $(SRC)\rexxsql_os2.res rexxsql.exe

#rexx$(db).dll: $(objsdbdll)
#	link386 $(lflagsdll) ut$(db)dll.o+hashdll.o+rx$(db)dll.o,$@,$*.map,$(DBLIBS),$(SRC)\rexx$(db)_os2_dll.def;
#	rc $(SRC)\rexxsql_os2.res rexx$(db).dll

#rexx$(db).exe: $(objsdbexe)
#	link386 $(lflagsexe) ut$(db)exe.o+rx$(db).o+hashexe.o+rx$(db)exe.o+getopt.o,$@,$*.map,$(DBLIBS),$(SRC)\rexx$(db)_os2_exe.def;
#	rc $(SRC)\rexxsql_os2.res rexx$(db).exe

dist: $(DISTDIR)
	rexx $(SRC)\dist\makedist.rex os2 $(LDB) $(VER_DOT)

$(DISTDIR):
	-mkdir $(DISTDIR)
#
# Rules for DEF files
#
rexxsqldll.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx SQL DLL OS2 rexxsqldll.def $(DB)

rexx$(LDB)dll.def: $(SRC)\makedef.rexx
	rexx $(SRC)\makedef.rexx $(DB) DLL OS2 rexx$(LDB)dll.def $(DB)
