
dnl
dnl include our own common routines
dnl
sinclude(common/accommon.m4)dnl

dnl ---------------------------------------------------------------------------
dnl Check for database header file
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_DB_HEADER],
[
db="$1"
head="$2"
mh_db_inc_dir=""
AC_MSG_CHECKING(location of $db header file)
db_inc_dirs="${db_inc_dirs}   \
    ${HOME}/include           \
    /usr/include/mysql        \
    /usr/local/include        \
    /usr/contrib/include      \
    /opt/include              \
    /usr/include              \
    /usr/unsupported/include"
if test "$with_dbincdir" = no; then
   for ac_dir in $db_inc_dirs ; do
     if test -f $ac_dir/$head; then
       mh_db_inc_dir=$ac_dir
       break
     fi
   done

   if test "x$mh_db_inc_dir" = "x"; then
     AC_MSG_ERROR($head not found; you MUST specify directory where $head resides using --with-dbincdir=)
   fi
else
  if test -f "$with_dbincdir/$head"; then
    mh_db_inc_dir="${with_dbincdir}"
  else
    AC_MSG_ERROR($head not found in $with_dbincdir)
  fi
fi
DB_INCLUDES="-I$mh_db_inc_dir"
AC_MSG_RESULT(found in $mh_db_inc_dir)
])dnl

dnl ---------------------------------------------------------------------------
dnl Check for database library file
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_DB_LIB],
[
db="$1"
lib="$2"
mh_db_lib_dir=""
AC_MSG_CHECKING(location of $db library file)
db_lib_dirs="${db_lib_dirs}   \
    ${HOME}/lib               \
    /usr/lib64/mysql          \
    /usr/lib/mysql            \
    /usr/local/lib            \
    /usr/contrib/lib          \
    /opt/lib                  \
    /opt/sfw/lib              \
    /usr/lib64                \
    /usr/lib                  \
    /usr/unsupported/lib"
if test "$with_dblibdir" = no; then
dnl look for lib$2.*
  for ac_dir in $db_lib_dirs ; do
    for mh_ext in so a sl lib dylib; do
      if test -r $ac_dir/lib$lib.$mh_ext; then
        mh_db_lib_dir=$ac_dir
        break 2
      fi
    done
  done
dnl look for $2.*
  if test "x$mh_db_inc_dir" = "x"; then
     for ac_dir in $db_lib_dirs ; do
       for mh_ext in so a sl lib dylib; do
         if test -r $ac_dir/$lib.$mh_ext; then
           mh_db_lib_dir=$ac_dir
           break 2
         fi
       done
     done
  fi
  if test "x$mh_db_lib_dir" = "x"; then
    AC_MSG_ERROR($db library not found; you MUST specify directory where $db lib$lib.* or $lib.* resides using --with-dblibdir=)
  fi
else
  for mh_ext in so a sl lib dylib; do
    if test -r "$with_dblibdir/lib$lib.$mh_ext" -o -r "$with_dblibdir/$lib.$mh_ext"; then
      mh_db_lib_dir="$with_dblibdir"
      break 2
    fi
  done
  if test "x$mh_db_lib_dir" = "x"; then
    AC_MSG_ERROR($db library not found in $with_dblibdir)
  fi
fi
DB_LIBS="-L$mh_db_lib_dir -l$lib"
AC_MSG_RESULT(found in $mh_db_lib_dir)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Oracle stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_ORACLE7],
[
dnl
dnl do the Oracle 8 checks first. if no library found that way do it the old way
dnl
MH_CHECK_ORACLE
if test -z $mh_db_lib_dir; then
	DBINC="oci.h"
	DBLIB1=""
	mh_db_inc_dir=""
	mh_db_lib_dir=""
	mh_db_name="Oracle"
	INCLUDE_DB_MAKEFILE=""
	if test -n "$ORACLE_HOME" ; then
		if test -f "$ORACLE_HOME/lib/libclntsh.$SHL"; then
			if test "$need_extra_oracle_libs" = yes; then
				DBLIB1="-L$ORACLE_HOME/lib -lclntsh -lcommon -lcore4 -lnlsrtl3"
			else
				DBLIB1="-L$ORACLE_HOME/lib -lclntsh"
			fi
			mh_db_lib_dir="$ORACLE_HOME/lib"
			nm $ORACLE_HOME/lib/libclntsh.$SHL | grep OCILogon > /dev/null
			if test $? -eq 0; then
				DBC="ora"
				DBH="ora"
				mh_db_inc_dir="$ORACLE_HOME/rdbms/demo"
			else
				DBC="ora7"
				DBH="ora7"
			fi
			AC_MSG_RESULT(using Oracle client library -lclntsh)
		else
			grep libclntsh $ORACLE_HOME/rdbms/lib/*.mk > /dev/null
			if test $? -eq 0 ; then
				AC_MSG_WARN(This version of Oracle supports a shared library of client code)
				AC_MSG_WARN(used by OCI programs.  The shared library; libclntsh.$SHL in)
				AC_MSG_WARN($ORACLE_HOME/lib has not been built.  See your DBA to build this)
				AC_MSG_WARN(library and then run this configuration script again.)
				AC_MSG_WARN(You will need to include $ORACLE_HOME/lib in your LD_LIBRARY_PATH.)
				AC_MSG_ERROR(configure aborted.)
			else
				if test -f "$ORACLE_HOME/rdbms/lib/oracle.mk" ; then
					INCLUDE_DB_MAKEFILE="include $ORACLE_HOME/rdbms/lib/oracle.mk"
					DBLIB1="-L$ORACLE_HOME/lib $(OCILDLIBS)"
					mh_db_lib_dir="$ORACLE_HOME/lib"
					AC_MSG_RESULT(using $ORACLE_HOME/rdbms/lib/oracle.mk)
				else
					AC_MSG_WARN(Unable to configure Rexx/SQL for Oracle.)
					AC_MSG_WARN(Rexx/SQL needs one of the following files to be available:)
					AC_MSG_WARN()
					AC_MSG_WARN($ORACLE_HOME/lib/libclntsh.$SHL)
					AC_MSG_WARN($ORACLE_HOME/rdbms/lib/oracle.mk)
					AC_MSG_WARN(or)
					AC_MSG_WARN(rules to make libclntsh.$SHL in)
					AC_MSG_WARN($ORACLE_HOME/rdbms/lib/*.mk)
				AC_MSG_ERROR(configure aborted.)
				fi
			fi
		fi
	else
		AC_MSG_ERROR(ORACLE_HOME not set cannot continue)
	fi
fi
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Oracle8 stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_ORACLE],
[
DBINC="oci.h"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="Oracle"
INCLUDE_DB_MAKEFILE=""

if test "$with_dbincdir" = no; then
	if test -f "$srcdir/$DBC/$DBINC"; then
		mh_db_inc_dir="$srcdir/$DBC"
		DB_INCLUDES="-I$mh_db_inc_dir"
	elif test -f "$ORACLE_HOME/include/$DBINC"; then
		mh_db_inc_dir="$ORACLE_HOME/include"
		DB_INCLUDES="-I${mh_db_inc_dir}"
	elif test -f "$ORACLE_HOME/rdbms/public/$DBINC"; then
		mh_db_inc_dir="$ORACLE_HOME/rdbms/public"
		DB_INCLUDES="-I${mh_db_inc_dir}"
	else
		AC_MSG_ERROR(cannot find $DBINC configure aborted)
	fi
else
	if test -f "$with_dbincdir/$DBINC"; then
		mh_db_inc_dir="$with_dbincdir"
		DB_INCLUDES="-I${mh_db_inc_dir}"
	else
		AC_MSG_ERROR(cannot find $with_dbincdir/$DBINC configure aborted)
	fi
fi

if test "x$bitflag" = "x32" -a -d "${ORACLE_HOME}/lib32"; then
	ora_arch_dir="${ORACLE_HOME}/lib32"
elif test "x$bitflag" = "x64" -a -d "${ORACLE_HOME}/lib64"; then
	ora_arch_dir="${ORACLE_HOME}/lib64"
else
	ora_arch_dir=""
fi

if test "$with_dblibdir" = no; then
	ora_lib_dirs="\
	    ${ora_arch_dir} \
	    ${ORACLE_HOME}/lib"
	for ac_dir in $ora_lib_dirs ; do
		for mh_ext in so a sl lib dylib; do
		  if test -r $ac_dir/libclntsh.$mh_ext; then
		     mh_db_lib_dir=$ac_dir
		     break 2
		  fi
		done
	done
	if test -z "$mh_db_lib_dir"; then
		AC_MSG_ERROR(cannot find libclntsh library configure aborted)
	else
		DBLIB1="-L${mh_db_lib_dir} -lclntsh"
	fi
else
	for mh_ext in so a sl lib dylib; do
	  if test -r $with_dblibdir/libclntsh.$mh_ext; then
	     mh_db_lib_dir=$with_dblibdir
	     break
	  fi
	done
	if test -z "$mh_db_lib_dir"; then
		AC_MSG_ERROR(cannot find libclntsh library in $with_dblibdir configure aborted)
	else
		DBLIB1="-L${mh_db_lib_dir} -lclntsh"
	fi
fi
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Sybase stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_SYBASE],
[
DBINC="ctpublic.h"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="Sybase System 10/11"
AC_MSG_CHECKING(for Sybase headers and libraries)
if test -n "$SYBASE" ; then
	if test "$with_dbincdir" = no; then
		DB_INCLUDES="-I${SYBASE}/include"
		mh_db_inc_dir="$SYBASE/include"
	else
		DB_INCLUDES="-I${with_dbincdir}"
		mh_db_inc_dir="$with_dbincdir"
	fi
	mh_db_lib_dir="$SYBASE/lib"
	mh_syb_libraries="cs tcl comn intl sybtcl insck"
	if test "$with_dblibdir" = no; then
		if test -f "${SYBASE}/lib/libctlib.a"; then
			mh_syb_lib="-lctlib"
		else
			if test -f "${SYBASE}/lib/libct.a"; then
				mh_syb_lib="-lct"
			fi
		fi
		for a_lib in $mh_syb_libraries; do
			if test -f "${SYBASE}/lib/lib${a_lib}.a"; then
				mh_syb_lib="${mh_syb_lib} -l${a_lib}"
			fi
		done
		DB_LIBS="-L${SYBASE}/lib ${mh_syb_lib}"
	else
		if test -f "${with_dblibdir}/libctlib.a"; then
			mh_syb_lib="-lctlib"
		else
			if test -f "${with_dblibdir}/libct.a"; then
				mh_syb_lib="-lct"
			fi
		fi
		for a_lib in $mh_syb_libraries; do
			if test -f "${with_dblibdir}/lib${a_lib}.a"; then
				mh_syb_lib="${mh_syb_lib} -l${a_lib}"
			fi
		done
		DB_LIBS="-L${with_dblibdir} ${mh_syb_lib}"
	fi
	AC_MSG_RESULT(found)
else
	AC_MSG_ERROR(SYBASE not set cannot continue)
fi
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all mSQL 2.x stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_MSQL],
[
DBINC="msql.h"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="miniSQL 2.x"
AC_MSG_CHECKING(location of mSQL header file)
if test "$with_dbincdir" = no; then
	if test -f "/usr/local/Hughes/include/msql.h"; then
		mh_db_inc_dir="/usr/local/Hughes/include"
	else
		AC_MSG_ERROR(msql.h not found in /usr/local/Hughes/include; you MUST specify directory where msql.h resides using --with-dbincdir=)
	fi
else
	if test -f "$with_dbincdir/msql.h"; then
		mh_db_inc_dir="${with_dbincdir}"
	else
		AC_MSG_ERROR(msql.h not found in $with_dbincdir)
	fi
fi
DB_INCLUDES="-I$mh_db_inc_dir"
AC_MSG_RESULT(found in $mh_db_inc_dir)

AC_MSG_CHECKING(location of mSQL library file)
if test "$with_dblibdir" = no; then
	if test -f "/usr/local/Hughes/lib/libmsql.a"; then
		mh_db_lib_dir="/usr/local/Hughes/lib"
	else
		AC_MSG_ERROR(libmsql.a not found in /usr/local/Hughes/lib; you MUST specify directory where libmsql.a resides using --with-dblibdir=)
	fi
else
	if test -f "$with_dblibdir/libmsql.a"; then
		mh_db_lib_dir="${with_dblibdir}"
	else
		AC_MSG_ERROR(libmsql.a not found in $with_dblibdir)
	fi
fi
DB_LIBS="-L$mh_db_lib_dir -lmsql"
AC_MSG_RESULT(found in $mh_db_lib_dir)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all mySQL stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_MYSQL],
[
DBINC="mysql.h"
DBLIB="mysqlclient"
DBLIB1=""
mh_db_name="MySQL"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all iODBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_IODBC],
[
DBINC="isql.h"
DBLIB="iodbc"
DBLIB1=""
mh_db_name="iODBC"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all unixODBC ODBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_UNIXODBC],
[
DBINC="sqlext.h"
DBLIB="odbc"
DBLIB1=""
mh_db_name="unixODBC"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all easysoft ODBC-ODBC bridge stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_EASYSOFT_OOB],
[
DBINC="odbc.h"
DBLIB="esoobclient"
db_inc_dirs="/usr/local/easysoft/oob/client/include"
db_lib_dirs="/usr/local/easysoft/oob/client/lib"
DBLIB1=""
mh_db_name="EasySoft ODBC-ODBC bridge"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Openlink ODBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_OPENLINK],
[
DBINC="isql.h"
DBLIB="iodbc"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="OpenLink ODBC"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Openlink UDBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_OPENLINK_UDBC],
[
DBINC="libudbc.h"
DBLIB="udbc"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="OpenLink UDBC"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Solid ODBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_SOLID],
[
DBINC="cli0defs.h"
DBLIB="colcli"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="Solid Server"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Velocis ODBC stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_VELOCIS],
[
DBINC="sqlext.h"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="Raima Velocis"
if test -n "$RDSHOME" ; then
	if test "$with_dbincdir" = no; then
		DB_INCLUDES="-I${RDSHOME}/include"
		mh_db_inc_dir="$RDSHOME/include"
	else
		DB_INCLUDES="-I${with_dbincdir}"
		mh_db_inc_dir="$with_dbincdir"
	fi

	if test "$with_dblibdir" = no; then
		DB_LIBS="-L${RDSHOME}/lib -lCadm -lCdict -lCenc -lCncp -lCrdbc -lCrdm -lCrm -lCrpc -lCuapi -lCsql"
		mh_db_lib_dir="$RDSHOME/lib"
	else
		DB_LIBS="-L${with_dblibdir} -lCadm -lCdict -lCenc -lCncp -lCrdbc -lCrdm -lCrm -lCrpc -lCuapi -lCsql"
		mh_db_lib_dir="$with_dblibdir"
	fi
else
	AC_MSG_ERROR(RDSHOME not set cannot continue)
fi
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all SqlAnywhere stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_SQLANYWHERE],
[
DBINC="unixodbc.h"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="Sybase SQL Anywhere"
if test -n "$ASANY9" ; then
	if test "$with_dbincdir" = no; then
		DB_INCLUDES="-I${ASANY9}/include"
		mh_db_inc_dir="$ASANY9/include"
	else
		DB_INCLUDES="-I${with_dbincdir}"
		mh_db_inc_dir="$with_dbincdir"
	fi
	if test "$with_dblibdir" = no; then
		DBLIB1="${ASANY9}/lib/saodbc.so"
		mh_db_lib_dir="$ASANY9/lib"
	else
		DBLIB1="${with_dblibdir}/saodbc.so"
		mh_db_lib_dir="$with_dblibdir"
	fi
else
	AC_MSG_ERROR(ASANY9 not set cannot continue)
fi
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all DB2 stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_DB2],
[
DBINC="sqlcli.h"
DBLIB="db2"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="IBM DB2"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all SQLite stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_SQLITE],
[
DBINC="sqlite.h"
DBLIB="sqlite"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="SQLite"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all SQLite3 stuff
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_CHECK_SQLITE3],
[
DBINC="sqlite3.h"
DBLIB="sqlite3"
DBLIB1=""
mh_db_inc_dir=""
mh_db_lib_dir=""
mh_db_name="SQLite3"
MH_CHECK_DB_HEADER($mh_db_name,$DBINC)
MH_CHECK_DB_LIB($mh_db_name,$DBLIB)
])dnl

dnl ---------------------------------------------------------------------------
dnl Setup all Makefile variables
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_SETUP_MAKEFILE],
[
case "$dbtouse" in
	oracle)
		DBH="ora"
		DBC="ora"
		LDB="ora"
		BDB="ORA"
		SDB=""
		dbsrc="ora"
		MH_CHECK_ORACLE
		;;
	oracle7)
		DBH="ora7"
		DBC="ora7"
		LDB="ora7"
		BDB="ORA7"
		SDB=""
		dbsrc="ora7"
		MH_CHECK_ORACLE7
		;;
	iodbc)
		DBH="odbc"
		DBC="cli-odbc"
		LDB="iodbc"
		BDB="IODBC"
		SDB="-DIODBC"
		dbsrc="rexxcli"
		MH_CHECK_IODBC
		;;
	openlink)
		DBH="odbc"
		DBC="cli-odbc"
		LDB="odbc"
		BDB="ODBC"
		SDB="-DOPENLINK"
		dbsrc="rexxcli"
		MH_CHECK_OPENLINK
		;;
	udbc)
		DBH="udbc"
		DBC="cli-odbc"
		LDB="udbc"
		BDB="UDBC"
		SDB="-DUDBC"
		SDB=""
		dbsrc="rexxcli"
		MH_CHECK_OPENLINK_UDBC
		;;
	intersolv)
		DBH="odbc"
		DBC="cli-odbc"
		LDB="odbc"
		BDB="ODBC"
		SDB="-DINTERSOLV"
		dbsrc="rexxcli"
		;;
	sybase)
		DBH="syb"
		DBC="syb"
		LDB="syb"
		BDB="SYB"
		SDB=""
		dbsrc="syb"
		MH_CHECK_SYBASE
		;;
	sqlanywhere)
		DBH="saw"
		DBC="cli-odbc"
		LDB="saw"
		BDB="SAW"
		SDB=""
		dbsrc="rexxcli"
		MH_CHECK_SQLANYWHERE
		;;
	msql)
		DBH="min2"
		DBC="min2"
		LDB="min"
		BDB="MIN"
		SDB=""
		dbsrc="min"
		MH_CHECK_MSQL
		;;
	mysql)
		DBH="my"
		DBC="my"
		LDB="my"
		BDB="MY"
		SDB=""
		dbsrc="my"
		MH_CHECK_MYSQL
		;;
	db2)
		DBH="db2"
		DBC="cli-odbc"
		LDB="db2"
		BDB="DB2"
		SDB=""
		dbsrc="rexxcli"
		MH_CHECK_DB2
		;;
	solid)
		DBH="sol"
		DBC="cli-odbc"
		LDB="sol"
		BDB="SOL"
		SDB="-DSS_UNIX -DSOLID_SERVER"
		dbsrc="rexxcli"
		MH_CHECK_SOLID
		;;
	velocis)
		DBH="vel"
		DBC="cli-odbc"
		LDB="vel"
		BDB="VEL"
		SDB="-DVELOCIS"
		dbsrc="rexxcli"
		MH_CHECK_VELOCIS
		;;
	unixodbc)
		DBH="odbc"
		DBC="cli-odbc"
		LDB="odbc"
		BDB="ODBC"
		SDB="-DUNIXODBC"
		dbsrc="rexxcli"
		MH_CHECK_UNIXODBC
		;;
	easysoft-oob)
		DBH="esoob"
		DBC="cli-odbc"
		LDB="esoob"
		BDB="ESOOB"
		SDB="-DEASYSOFT_OOB"
		dbsrc="rexxcli"
		MH_CHECK_EASYSOFT_OOB
		;;
	sqlite)
		DBH="sqlite"
		DBC="sqlite"
		LDB="lite"
		BDB="LITE"
		SDB="-DSQLITE"
		dbsrc="sqlite"
		MH_CHECK_SQLITE
		;;
	sqlite3)
		DBH="sqlite3"
		DBC="sqlite3"
		LDB="lite3"
		BDB="LITE3"
		SDB="-DSQLITE3"
		dbsrc="sqlite3"
		MH_CHECK_SQLITE3
		;;
	none)
		;;
	*)
		AC_MSG_ERROR("No database specified to be configured. Use --with-db=oracle7|oracle|db2|mysql|msql|unixodbc|iodbc|openlink|udbc|easysoft-oob|solid|velocis|intersolv|sqlanywhere|sybase|sqlite|sqlite3")
		;;
esac
MH_PACKAGE_LIBS="$DB_LIBS $DBLIB1"
AC_SUBST(MH_PACKAGE_LIBS)
AC_SUBST(DBH)
AC_SUBST(DEFS)
AC_SUBST(DBC)
AC_SUBST(LDB)
AC_SUBST(BDB)
AC_SUBST(SDB)
AC_SUBST(dbsrc)
AC_SUBST(DB_LIBS)
AC_SUBST(DB_INCLUDES)
AC_SUBST(DBLIB1)
AC_SUBST(INCLUDE_DB_MAKEFILE)
])dnl

dnl ---------------------------------------------------------------------------
dnl Shows where database header/libraries are
dnl Called from MH_SHOW_STATUS
dnl ---------------------------------------------------------------------------
AC_DEFUN([MH_SHOW_DB],
[
echo "                         Database: $mh_db_name"
echo "              Database headers in: $mh_db_inc_dir"
echo "            Database libraries in: $mh_db_lib_dir"
])
