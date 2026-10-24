/*
 * This program is the test suite for Rexx/SQL
 *
 * To use it you must do the following:
 * 1.  set environment variables REXXSQL_USERNAME, REXXSQL_PASSWORD,
 *     REXXSQL_DATABASE and REXXSQL_SERVER to values appropriate for
 *     the database you are connecting to. See the documentation for
 *     which values you need.
 *     Some values for each tested database follows:
 *
 *     Database             REXXSQL_USERNAME REXXSQL_PASSWORD REXXSQL_DATABASE REXXSQL_SERVER
 *     --------------------------------------------------------------------------------------
 *     ORACLE               SCOTT            TIGER
 *     ORACLE8              SCOTT            TIGER            SID              hostname
 *     ORACLE8              SCOTT            TIGER                             machine:1521/SID
 *     SQLAnyWhere          dba              sql              SADEMO           MYTNSENTRY
 *     DB2                  userid           password         SAMPLE
 *     mySQL                                                  REXXSQL
 *     mSQL                                                   REXXSQL
 *     ODBC(Access)                                           REXXSQL
 *     ODBC(Solid)          scott            tiger
 *     ODBC(ISR)                                              ISRTEST
 *     Solid Server(NT)     system           manager          NmPipe SOLID
 *     Solid Server(NT)     system           manager
 *     Openlink UDBC        scott            tiger            default
 *     Microsoft SQL Server myuser           mypass           MYDSN
 *     PostgresSQL (iODBC)  system           manager          REXXSQL
 *     Velocis (RDS)        admin            secret           RDS
 *     SQLite                                                 <filename>
 * 2.  Run this Rexx/SQL program with a parameter of "setup". This creates
 *     the two test tables; RX_EMP and RX_DEPT.
 * 3.  Run this Rexx/SQL program with no parameters. This runs the complete
 *     test suite. Alternately, you can run each individual test by specifying
 *     its name as the only parameter. The valid values are specified below
 *     in the variable "exercise".
*/
Signal on Syntax
Trace o
exercise = 'connections describe fetch command placemarker transaction extra info errors'
Parse Source . method .
If initialise(method) Then Exit 1
Parse Arg test .
If test = '' Then
   Do
      Say '***** Running tests:' exercise '*****'
      Do i = 1 To Words(exercise)
         Interpret Call Word(exercise,i)
      End
   End
Else
  Do
    If Datatype(test,'NUM') Then runtest = Word(exercise,test)
    Else runtest = test
    Say '***** Running test:' runtest '*****'
    Interpret Call runtest
  End
Call finalise
Return

/*-----------------------------------------------------------------*/
initialise:
Parse Arg method
Call RXFuncAdd 'SQLLoadFuncs','rexxsql','SQLLoadFuncs'
Call SqlLoadFuncs
version = sqlvariable('VERSION')
Parse Version rxver
Say version 'with:' rxver
Parse Var version . . . . . os db .
Parse Version ver .
db = Translate(db)
select
  when os = 'UNIX' & ver = 'REXXSAA' Then envname = 'ENVIRONMENT'
  when os = 'UNIX' & ver = 'OBJREXX' Then envname = 'ENVIRONMENT'
  when Left( ver, 11 ) = 'REXX-ooRexx' Then envname = 'ENVIRONMENT'
  when os = 'UNIX' Then envname = 'SYSTEM'
  when os = 'WIN32' Then envname = 'ENVIRONMENT'
  when os = 'OS/2' Then envname = 'OS2ENVIRONMENT'
  otherwise Say 'Unsupported platform'
end

sqlconnect.1 = Value('REXXSQL_USERNAME',,envname)
sqlconnect.2 = Value('REXXSQL_PASSWORD',,envname)
sqlconnect.3 = Value('REXXSQL_DATABASE',,envname)
sqlconnect.4 = Value('REXXSQL_SERVER'  ,,envname)
columnnames_emp  = 'empid deptno mgrid empname startdt enddt salary dbname'
columnnames_dept = 'deptno deptname dbname'

Return 0

/*-----------------------------------------------------------------*/
finalise:
Call SqlDropFuncs 'UNLOAD'
Return

/*-----------------------------------------------------------------*/
connect: Procedure Expose sqlca. sqlconnect.
Parse Arg id .
If sqlconnect(id,sqlconnect.1,sqlconnect.2,sqlconnect.3,sqlconnect.4) < 0 Then Call Abort 'connect'
Say 'connect: succeeded for <'id'> <'sqlconnect.1'> <'sqlconnect.2'> <'sqlconnect.3'> <'sqlconnect.4'>'
Return

/*-----------------------------------------------------------------*/
disconnect: Procedure Expose sqlca.
Parse Arg id
If sqldisconnect(id) < 0 Then Call Abort 'disconnect'
Say 'disconnect: succeeded for <'id'>'
Return

/*-----------------------------------------------------------------*/
setup: Procedure Expose sqlca. sqlconnect. db columnnames_emp columnnames_dept columndata_dept. columndata_emp. datetype dateformat
months = 'JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC'

Call setdatatypes

columntypes_emp.1 = numbertype 'not null,'
columntypes_emp.2 = numbertype 'not null,'
columntypes_emp.3 = numbertype 'not null,'
columntypes_emp.4 = chartype 'not null,'
columntypes_emp.5 = datetype ','
columntypes_emp.6 = datetype ','
columntypes_emp.7 = moneytype 'not null,'
columntypes_emp.8 = chartype
columntypes_dept.1 = numbertype 'not null,'
columntypes_dept.2 = chartype 'not null,'
columntypes_dept.3 = chartype

columndata_emp.0 = 3
columndata_emp.0.0 = 7
columndata_emp.1.1 = 1
columndata_emp.1.2 = 10
columndata_emp.1.3 = 0
columndata_emp.1.4 = "'Joe Bloggs'"
columndata_emp.1.5 = 19990126
columndata_emp.1.6 = 'NULL'
columndata_emp.1.7 = 556.22
columndata_emp.2.1 = 2
columndata_emp.2.2 = 10
columndata_emp.2.3 = 1
columndata_emp.2.4 = "'Mary Jones'"
columndata_emp.2.5 = 19910226
columndata_emp.2.6 = 19960126
columndata_emp.2.7 = 202.04
columndata_emp.3.1 = 3
columndata_emp.3.2 = 30
columndata_emp.3.3 = 1
columndata_emp.3.4 = "'Steve Brown'"
columndata_emp.3.5 = 19950504
columndata_emp.3.6 = NULL
columndata_emp.3.7 = 345.00
columndata_dept.0 = 2
columndata_dept.0.0 = 2
columndata_dept.1.1 = 10
columndata_dept.1.2 = "'Department 10'"
columndata_dept.2.1 = 20
columndata_dept.2.2 = "'Department 20'"

Say Copies('*',20)
Say 'setup: Creating test tables...'
Say Copies('*',20)
Call connect 'c1'
dbcon = sqlgetinfo('c1','DBMSNAME')
src = "'"||dbcon||"'"
create1 = 'create table RX_EMP ('
Do i = 1 To Words(columnnames_emp)
   create1 = create1 Word(columnnames_emp,i) columntypes_emp.i
End
create1 = create1 ')'
/*
 * If MySQL, add table options to allow transactions
 */
If db = 'MYSQL' Then create1 = create1 'TYPE = InnoDB'
Call create_test_table 'RX_EMP' create1

create1 = 'create table RX_DEPT ('
Do i = 1 To Words(columnnames_dept)
   create1 = create1 Word(columnnames_dept,i) columntypes_dept.i
End
create1 = create1 ')'
/*
 * If MySQL, add table options to allow transactions
 */
If db = 'MYSQL' Then create1 = create1 'TYPE = InnoDB'
Call create_test_table 'RX_DEPT' create1
/*
 If SQLITE create a transaction
 */
If db = 'SQLITE' | db = 'SQLITE3' Then
  Do
    Say 'transaction: Setting explicit transaction for' db
    If sqlcommand('q1','begin transaction') < 0 Then Call Abort 'setup: begin transaction'
  End
Do i = 1 To columndata_emp.0
   c1 = "insert into RX_EMP values("
   Do j = 1 To columndata_emp.0.0
      If Word(columntypes_emp.j,1) = datetype & columndata_emp.i.j \= NULL Then
         Do
            If dateformat = "'DD-MON-YY'" Then
               Do
                  mon = Substr(columndata_emp.i.j,5,2)
                  c1 = c1 "'" || Substr(columndata_emp.i.j,7,2) || '-' || Word(months,mon) || '-' || Substr(columndata_emp.i.j,3,2) || "',"
               End
            Else c1 = c1 Translate(dateformat,columndata_emp.i.j,'12345678') ","
         End
      Else c1 = c1 columndata_emp.i.j ","
   End
   c1 = c1 src ")"
   If sqlcommand('c1',c1) < 0 Then Call Abort 'setup: inserting into RX_EMP table'
   If sqlvariable('SUPPORTSDMLROWCOUNT') = 1 Then Say 'setup:' sqlca.rowcount 'row(s) inserted successfully'
   Else Say 'setup: setting of SQLCA.ROWCOUNT for DML not supported; insert succeeded'
End

Do i = 1 To columndata_dept.0
   c2 = "insert into RX_DEPT values("
   Do j = 1 To columndata_dept.0.0
      c2 = c2 columndata_dept.i.j ","
   End
   c2 = c2 src ")"
   If sqlcommand('c2',c2) < 0 Then Call Abort 'setup: inserting into RX_DEPT table'
   If sqlvariable('SUPPORTSDMLROWCOUNT') = 1 Then Say 'setup:' sqlca.rowcount 'row(s) inserted successfully'
   Else Say 'setup: setting of SQLCA.ROWCOUNT for DML not supported; insert succeeded'
End
If sqlcommit() < 0 Then Call Abort 'setup: commiting'
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
setdatatypes:
chartypes = 'VARCHAR2(30) VARCHAR(30) CHAR(30) CHARACTER(30)'
numbertypes = 'NUMBER(5) SMALLINT INT NUMERIC(5) NUMERIC LONG BYTE NUMBER'
moneytypes = 'MONEY CURRENCY DECIMAL(10,2) DECIMAL NUMBER(10,2) NUMERIC(10,2) REAL FLOAT'
datetypes = 'DATE DATETIME CHAR(8)'
dateformats.1 = "'1234-56-78'"     /* 'YYYY-MM-DD' */
dateformats.2 = "'DD-MON-YY'"      /* can't use TRANSLATE on this format */
dateformats.3 = "'12345678'"       /* 'YYYYMMDD' */
dateformats.4 = "'78/56/1234'"     /* 'DD/MM/YYYY' */
dateformats.5 = "'56/78/1234'"     /* 'MM/DD/YYYY' */
dateformats.6 = "{d 1234-56-78}"   /* {d YYYY-MM-DD} */
dateformats.0 = 6
chartype = ''
numbertype = ''
moneytype = ''
datetype = ''
dateformat = ''

Call connect 'c1'
If sqlgetinfo('c1','DATATYPES','datatypes.') < 0 Then Call Abort  'setdatatypes: unable to determine datatypes'
/*
 * Determine valid CHAR type
 */
Do i = 1 To Words(chartypes)
   atype = Word(chartypes,i)
   Parse Var atype type '(' .
   Do j = 1 To datatypes.0
      If Translate(datatypes.j) = type Then
         Do
            Call sqlcommand 'd1','drop table RX_TEST'
            Call sqlcommit 'c1'
            If sqlcommand('t1','create table RX_TEST( col1' atype ')') = 0 Then
               Do
                  If sqlcommand('i1',"insert into RX_TEST values('abc')") = 0 Then
                     Do
                        chartype = atype
                        Call sqlcommit 'c1'
                        Leave i
                     End
               End
         End
   End
End
If chartype = '' Then Call Abort  'setdatatypes: unable to determine datatype for CHAR. Datatype is:' atype

/*
 * Determine valid NUMBER type
 */
Do i = 1 To Words(numbertypes)
   atype = Word(numbertypes,i)
   Parse Var atype type '(' .
   Do j = 1 To datatypes.0
      If Translate(datatypes.j) = type Then
         Do
            Call sqlcommand 'd1','drop table RX_TEST'
            Call sqlcommit 'c1'
            If sqlcommand('t1','create table RX_TEST( col1' atype ')') = 0 Then
               Do
                  If sqlcommand('i1',"insert into RX_TEST values(10)") = 0 Then
                     Do
                        numbertype = atype
                        stringdatatypes_empid = type
                        stringdatatypes_deptno = type
                        Call sqlcommit 'c1'
                        Leave i
                     End
               End
         End
   End
End
If numbertype = '' Then Call Abort  'setdatatypes: unable to determine datatype for NUMBER'

/*
 * Determine valid MONEY type
 */
Do i = 1 To Words(moneytypes)
   atype = Word(moneytypes,i)
   Parse Var atype type '(' .
   Do j = 1 To datatypes.0
      If Translate(datatypes.j) = type Then
         Do
            Call sqlcommand 'd1','drop table RX_TEST'
            Call sqlcommit 'c1'
            If sqlcommand('t1','create table RX_TEST( col1' atype ')') = 0 Then
               Do
                  If sqlcommand('i1',"insert into RX_TEST values(566.22)") = 0 Then
                     Do
                        moneytype = atype
                        stringdatatypes_salary = type
                        Call sqlcommit 'c1'
                        Leave i
                     End
               End
         End
   End
End
If moneytype = '' Then Call Abort  'setdatatypes: unable to determine datatype for MONEY'

/*
 * Determine valid DATE type
 */
Do i = 1 To Words(datetypes)
   atype = Word(datetypes,i)
   Parse Var atype type '(' .
   Do j = 1 To datatypes.0
      If Translate(datatypes.j) = type Then
         Do
            Call sqlcommand 'd1','drop table RX_TEST'
            Call sqlcommit 'c1'
            If sqlcommand('t1','create table RX_TEST( col1' atype ')') = 0 Then
               Do
                  Do k = 1 To dateformats.0
                     If dateformats.k = "'DD-MON-YY'" Then testdate = "'25-JAN-99'"
                     Else testdate = Translate(dateformats.k,'19990125','12345678')
                     If sqlcommand('i1',"insert into RX_TEST values(" testdate ")") = 0 Then
                        Do
                           datetype = atype
                           dateformat = dateformats.k
                           Call sqlcommit 'c1'
                           Leave i
                        End
                  End
               End
         End
   End
End
If datetype = '' Then Call Abort  'setdatatypes: unable to determine datatype for DATE'
Call sqlcommand 'd1','drop table RX_TEST'
Call disconnect 'c1'

Return

/*-----------------------------------------------------------------*/
create_test_table: Procedure Expose sqlca.
Parse Arg table_name create_string
rc = sqlcommand('c1','drop table' table_name)
If rc \= 0 Then
   Do
      Say 'The following error is valid if the table did not exist.'
      Say sqlca.sqlerrm
   End
rc = sqlcommit()
If rc \= 0 Then
   Do
      Say 'The following error is valid if the table did not exist.'
      Say sqlca.sqlerrm
   End
If sqlcommand('c1',create_string) < 0 Then Call Abort 'setup: creating' table_name 'table'
rc = sqlcommit()
Say 'setup:' table_name 'created successfully'
Return

/*-----------------------------------------------------------------*/
connections: Procedure Expose sqlca. sqlconnect.
Say Copies('*',20)
Say 'Testing multiple connections/disconnections...'
Say Copies('*',20)
Call connect 'c1'
Call connect 'c2'
Call connect 'c3'
Call disconnect 'c1'
Call disconnect 'c2'
Call disconnect 'c3'
Return

/*-----------------------------------------------------------------*/
describe: Procedure Expose sqlca. sqlconnect. db os
Say Copies('*',20)
Say 'Testing statement descriptions...'
Say Copies('*',20)
Select
  When db = 'ORACLE' & os = 'OS/2' Then
    Do
      query1 = 'select * from RX_EMP order by empid'
/*  query1 = 'select empid,empname from RX_EMP'*/
/*  query1 = 'select * from RX_EMP a, RX_DEPT b where a.deptno = b.deptno'*/
      Say Copies('*',30)
      Say 'The OS/2 port of Oracle (at least 7.0.xx) does not'
      Say 'correctly describe the following statement:'
      Say ' select * from RX_EMP'
      Say Copies('*',30)
    End
  When db = 'SQLITE' | db = 'SQLITE3' Then
    Do
      /*
       * Can only describe tables, not SELECT statements
       */
      query1 = 'RX_EMP'
    End
  Otherwise
    Do
      query1 = 'select * from RX_EMP'
    End
End
Call connect 'c1'
If sqlgetinfo('c1','DESCRIBECOLUMNS','desc.') < 0 Then Call Abort 'describe: getting describe columns'
Do i = 1 To desc.0
   width.i = Length(desc.i)
End
Say 'describe: Describing <'|| query1 ||'>'
If sqlprepare('p1',query1) < 0 Then Call Abort 'describe: preparing'
If sqldescribe('p1') < 0 Then Call Abort 'describe: describing'
col = desc.1
num_rows = p1.column.col.0
Do i = 1 To num_rows
   Do j = 1 To desc.0
      col = desc.j
      col_val = p1.column.col.i
      if Length(col_val) > width.j Then width.j = Length(col_val)
   End
End
line = ''
line_len = 0
Do i = 1 To desc.0
   line = line Left(desc.i,width.i)
   line_len = line_len + 1 + width.i
End
Say line
Say Copies('-',line_len)
Do i = 1 To num_rows
   line = ''
   Do j = 1 To desc.0
      col = desc.j
      line = line Left(p1.column.col.i,width.j)
   End
   Say line
End
If sqlclose('p1') < 0 Then Call Abort 'describe: closing'
If sqldispose('p1') < 0 Then Call Abort 'describe: disposing'
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
extra: Procedure Expose sqlca. sqlconnect. db os
/*
 * Some databases require a connection for sqldatasources();
 * others don't but it doesn't matter
 */
Call connect 'c1'
Say Copies('*',20)
Say 'Testing sqldatasources()...'
Say Copies('*',20)
rc = sqlvariable('NULLSTRINGOUT','')
If sqldatasources('ds') < 0 Then Call Abort 'datasources: getting datasources'
Do i = 1 To ds.dsn_name.0
   Say 'Data Source:' ds.dsn_name.i '::' ds.dsn_description.i
End
Drop ds.
Say Copies('*',20)
Say 'Testing sqltables()...'
Say Copies('*',20)
If sqltables('t') < 0 Then Call Abort 'tables: getting tables'
Say '      ' Left('Catalog', 20) Left('Owner', 20) Left('Table Name', 30) Left('Type',20) 'Description'
Do i = 1 To t.table_catalog.0
   Say 'Table:' Left(t.table_catalog.i,20) Left(t.table_owner.i,20) Left(t.table_name.i,30) Left(t.table_type.i,20) t.table_description.i
End
Drop t.
Say Copies('*',20)
Say 'Testing sqlcolumns() for RX_EMP...'
Say Copies('*',20)
If sqlcolumns('c',,,'RX_EMP') < 0 Then Call Abort 'columns: getting columns'
Say '       ' Left('Catalog', 20) Left('Owner', 20) Left('Table Name', 30) Left('Column Name', 30) Left('Type',20) Left('Precision',10) Left('Size',10) Left('Scale',10) Left('Nullable',5) 'Description'
Do i = 1 To c.table_catalog.0
   Say 'Column:' Left(c.table_catalog.i,20) Left(c.table_owner.i,20) Left(c.table_name.i,30) Left(c.column_name.i,30) Left(c.column_type.i,20) Left(c.column_precision.i,10) Left(c.column_size.i,10) Left(c.column_scale.i,10) Left(c.column_nullable.i,5) c.column_description.i
End
Drop c.
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
fetch: Procedure Expose sqlca. sqlconnect. columnnames_emp columnnames_dept db os
Say Copies('*',20)
Say 'Testing sqlprepare/sqlopen/sqlfetch...'
Say Copies('*',20)
If db = 'ORACLE' & os = 'OS/2' Then
  Do
    query1 = 'select * from RX_EMP order by empid'
/*  query1 = 'select empid,empname from RX_EMP'*/
/*  query1 = 'select * from RX_EMP a, RX_DEPT b where a.deptno = b.deptno'*/
    Say Copies('*',30)
    Say 'The OS/2 port of Oracle (at least 7.0.xx) does not'
    Say 'correctly describe the following statement:'
    Say ' select * from RX_EMP'
    Say Copies('*',30)
  End
Else
  query1 = 'select * from RX_EMP'
Call connect 'c1'
rc = sqlvariable('NULLSTRINGOUT','<null>')
Say 'fetch: Single row Fetching for <'|| query1 ||'>'
If sqlprepare('p1',query1) < 0 Then Call Abort 'fetch: preparing'
If sqlopen('p1') < 0 Then Call Abort 'fetch: opening(1)'
Do Forever
   rc = sqlfetch('p1')
   If rc < 0 then Call Abort 'fetch: fetching(1)'
   If rc = 0 Then Leave
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col
   End
   Say line
End
If sqlclose('p1') < 0 Then Call Abort 'fetch: closing(1)'
If sqldispose('p1') < 0 Then Call Abort 'fetch: disposing(1)'

If sqlprepare('p1',query1) < 0 Then Call Abort 'fetch: preparing(2)'
Say 'fetch: Multiple row Fetching for <'|| query1 ||'>'
If sqlopen('p1') < 0 Then Call Abort 'fetch: opening(2)'
rc = sqlfetch('p1',100)
If rc < 0 then Call Abort 'fetch: fetching(2)'
Do i = 1 To rc
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col.i
   End
   Say line
End
If sqlclose('p1') < 0 Then Call Abort 'fetch: closing(2)'
If sqldispose('p1') < 0 Then Call Abort 'fetch: disposing(2)'
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
command: Procedure Expose sqlca. sqlconnect. columnnames_emp columnnames_dept
Say Copies('*',20)
Say 'Testing sqlcommand...'
Say Copies('*',20)
query1 = "select * from RX_EMP"
Call connect 'c1'
rc = sqlvariable('NULLSTRINGOUT','<null>')
Say 'command: <'|| query1 ||'>'
If sqlcommand('p1',query1) < 0 Then Call Abort 'command: executing'
Say 'command:' sqlca.rowcount 'row(s) retrieved successfully'
col = Translate(Word(columnnames_emp,1))
num_rows = p1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col.i
   End
   Say line
End
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
placemarker: Procedure Expose sqlca. sqlconnect. os db columnnames_emp columnnames_dept stringdatatypes_empid stringdatatypes_deptno stringdatatypes_salary
Say Copies('*',20)
Say 'Testing sqlcommand with placemarkers...'
Say Copies('*',20)

Call setdatatypes

If sqlvariable('SUPPORTSPLACEMARKERS') = 0 Then
  Do
     Say 'Rexx/SQL does not support the use of placemarkers in queries for this database. This test ignored.'
     Return
  End
query1 = "select * from RX_EMP where empid = ? and deptno = ?"
Call connect 'c1'
rc = sqlvariable('NULLSTRINGOUT','<null>')
rc = sqlvariable('STANDARDPLACEMARKERS',1)
Say 'placemarker: (normal): <'|| query1 ||'>'
If sqlcommand('p1',query1,stringdatatypes_empid,1,stringdatatypes_deptno,10) < 0 Then Call Abort 'placemarker: (normal) executing'
col = Translate(Word(columnnames_emp,1))
num_rows = p1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col.i
   End
   Say line
End
Say 'placemarker:  (array): <'|| query1 ||'>'
dt.0 = 2
dt.1 = stringdatatypes_empid
dt.2 = stringdatatypes_deptno
dv.0 = 2
dv.1 = 1
dv.2 = 10
If sqlcommand('p1',query1,'dt.','dv.') < 0 Then Call Abort 'placemarker: (array) executing'
col = Translate(Word(columnnames_emp,1))
num_rows = p1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col.i
   End
   Say line
End
Say 'placemarker:   (file): <'|| query1 ||'>'
ei_file = 'empid.tmp'
dn_file = 'deptno.tmp'
If os = 'UNIX' Then
  Do
    Address System 'rm' ei_file
    Address System 'rm' dn_file
  End
Else
  Do
    Address System 'del' ei_file
    Address System 'del' dn_file
  End
rc = Charout(ei_file,,1)
rc = Charout(ei_file,'1')
rc = Charout(ei_file)
rc = Charout(dn_file,,1)
rc = Charout(dn_file,'10')
rc = Charout(dn_file)
dt.0 = 2
dt.1 = 'FILE:'||stringdatatypes_empid
dt.2 = 'FILE:'||stringdatatypes_deptno
dv.0 = 2
dv.1 = ei_file
dv.2 = dn_file
If sqlcommand('p1',query1,'dt.','dv.') < 0 Then Call Abort 'placemarker: (file) executing'
col = Translate(Word(columnnames_emp,1))
num_rows = p1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_emp)
      col = Translate(Word(columnnames_emp,j))
      line = line p1.col.i
   End
   Say line
End
If db = 'ORACLE' Then
   Do
      /*
       * If connecting to Oracle via OCI try and use Oracle's
       * bind variable syntax. This doesn't seem to work with ODBC.
       */
      rc = sqlvariable('STANDARDPLACEMARKERS',0)
      query1 = "select * from RX_EMP where empid = :1 and deptno = :2"
      Say 'placemarker: (oracle-normal-number): <'|| query1 ||'>'
      If sqlcommand('p1',query1,'#',1,10) < 0 Then Call Abort 'placemarker: (oracle-normal-number) executing'
      col = Translate(Word(columnnames_emp,1))
      num_rows = p1.col.0
      Do i = 1 To num_rows
         line = ''
         Do j = 1 To Words(columnnames_emp)
            col = Translate(Word(columnnames_emp,j))
            line = line p1.col.i
         End
         Say line
      End
      Say 'placemarker:  (oracle-array-number): <'|| query1 ||'>'
      dv.0 = 2
      dv.1 = 1
      dv.2 = 10
      If sqlcommand('p1',query1,'.','dv.') < 0 Then Call Abort 'placemarker: (oracle-array-number) executing'
      col = Translate(Word(columnnames_emp,1))
      num_rows = p1.col.0
      Do i = 1 To num_rows
         line = ''
         Do j = 1 To Words(columnnames_emp)
            col = Translate(Word(columnnames_emp,j))
            line = line p1.col.i
         End
         Say line
      End
      query1 = "select * from RX_EMP where empid = :empid and deptno = :deptno"
      Say 'placemarker: (oracle-normal-name): <'|| query1 ||'>'
      If sqlcommand('p1',query1,':empid',1,':deptno',10) < 0 Then Call Abort 'placemarker: (oracle-normal-name) executing'
      col = Translate(Word(columnnames_emp,1))
      num_rows = p1.col.0
      Do i = 1 To num_rows
         line = ''
         Do j = 1 To Words(columnnames_emp)
            col = Translate(Word(columnnames_emp,j))
            line = line p1.col.i
         End
         Say line
      End
      Say 'placemarker:  (oracle-array-name): <'|| query1 ||'>'
      dn.0 = 2
      dn.1 = ':empid'
      dn.2 = ':deptno'
      dv.0 = 2
      dv.1 = 1
      dv.2 = 10
      If sqlcommand('p1',query1,'.','dn.','dv.') < 0 Then Call Abort 'placemarker: (oracle-array-name) executing'
      col = Translate(Word(columnnames_emp,1))
      num_rows = p1.col.0
      Do i = 1 To num_rows
         line = ''
         Do j = 1 To Words(columnnames_emp)
            col = Translate(Word(columnnames_emp,j))
            line = line p1.col.i
         End
         Say line
      End
   End
/*
 * Now test standard placemarkers in DML...
 */
rc = sqlvariable('STANDARDPLACEMARKERS',1)
query1 = 'update rx_emp set salary = ? where empid = ?'
Say 'placemarker:   (updating): <'|| query1 ||'>'
If sqlcommand('q1','select empid, salary from rx_emp order by empid' ) < 0 Then Call Abort 'placemarker: command(1)'
If sqlprepare('q2',query1) < 0 Then Call Abort 'placemarker: preparing'
Do i = 1 To q1.empid.0
   Say 'Empid:' q1.empid.i 'had original salary of' q1.salary.i
   sal = q1.salary.i + (100 * i)
   If sqlexecute('q2',stringdatatypes_salary, sal, stringdatatypes_empid, q1.empid.i) < 0 Then Call Abort 'placemarker: executing'
End
If sqldispose('q2') < 0 Then Call Abort 'placemarker: disposing'
If sqlcommand('q1','select empid, salary from rx_emp order by empid' ) < 0 Then Call Abort 'placemarker: command(2)'
Do i = 1 To q1.empid.0
   Say 'Empid:' q1.empid.i 'now has salary of' q1.salary.i
End
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
transaction: Procedure Expose sqlca. sqlconnect. db columnnames_emp columnnames_dept
Say Copies('*',20)
Say 'Testing transactions and sqlexecute...'
Say Copies('*',20)
select1 = "select * from RX_DEPT"
insert1 = "insert into RX_DEPT values (100,'Department 100 - new','dummy')"
insert2 = "insert into RX_DEPT values (200,'Department 200 - new','dummy')"
Call connect 'c1'
rc = sqlvariable('NULLSTRINGOUT','<null>')
Say 'transaction: Contents of RX_DEPT before INSERTs'
If sqlcommand('q1',select1) < 0 Then Call Abort 'transaction: executing'
col = Translate(Word(columnnames_dept,1))
num_rows = q1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_dept)
      col = Translate(Word(columnnames_dept,j))
      line = line q1.col.i
   End
   Say line
End
If db = 'SQLITE' | db = 'SQLITE3' Then
  Do
    Say 'transaction: Setting explicit transaction for' db
    If sqlcommand('q1','begin transaction') < 0 Then Call Abort 'transaction: begin transaction'
  End
Say 'transaction: Inserting 2 rows into RX_DEPT'
If sqlcommand('q1',insert1) < 0 Then Call Abort 'transaction: executing'
If sqlvariable('SUPPORTSDMLROWCOUNT') = 1 Then Say 'transaction:' sqlca.rowcount 'row(s) inserted successfully via sqlcommand()'
Else Say 'transaction: setting of SQLCA.ROWCOUNT for DML not supported; insert succeeded  via sqlcommand()'
If sqlprepare('q2',insert2) < 0 Then Call Abort 'transaction: preparing'
If sqlexecute('q2') < 0 Then Call Abort 'transaction: executing'
If sqlvariable('SUPPORTSDMLROWCOUNT') = 1 Then Say 'transaction:' sqlca.rowcount 'row(s) inserted successfully via sqlexecute()'
Else Say 'transaction: setting of SQLCA.ROWCOUNT for DML not supported; insert succeeded via sqlexecute()'
If sqldispose('q2') < 0 Then Call Abort 'transaction: disposing'
Say 'transaction: Contents of RX_DEPT after INSERTs'
If sqlcommand('q1',select1) < 0 Then Call Abort 'transaction: executing'
col = Translate(Word(columnnames_dept,1))
num_rows = q1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_dept)
      col = Translate(Word(columnnames_dept,j))
      line = line q1.col.i
   End
   Say line
End
Say 'transaction: Rolling back transaction'
If sqlgetinfo('c1','SUPPORTSTRANSACTIONS') = 0 Then
   Say '***' db 'does not support the use of transactions. Rollback is ignored.'
rc = sqlrollback()
If rc < 0 Then Call Abort 'transaction: rolling back'
If rc > 0 Then Call Abort 'transaction: rolling back - warning:', 1
Say 'transaction: Contents of RX_DEPT after ROLLBACK'
If sqlcommand('q1',select1) < 0 Then Call Abort 'transaction: executing'
col = Translate(Word(columnnames_dept,1))
num_rows = q1.col.0
Do i = 1 To num_rows
   line = ''
   Do j = 1 To Words(columnnames_dept)
      col = Translate(Word(columnnames_dept,j))
      line = line q1.col.i
   End
   Say line
End
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
errors: Procedure Expose sqlca. sqlconnect. db columnnames_emp columnnames_dept
Say Copies('*',20)
Say 'Testing error conditions...'
Say Copies('*',20)
Say 'errors: causing error in sqlconnect()... (may take a while to fail!)'
If sqlconnect('c1','junk','junk','junk','junk') < 0 Then Call Abort 'connect:',1
Say 'errors: causing errors in sqlcommand()...'
If sqlcommand('q1','select abc from junk') < 0 Then Call Abort 'command:',1
Call connect 'c1'
If sqlcommand('q1','select abc from junk') < 0 Then Call Abort 'command:',1
Say 'errors: causing error in sqlexecute()...'
If sqlexecute('q1') < 0 Then Call Abort 'execute:',1
Say 'errors: causing error in sqlopen()...'
If sqlopen('q1') < 0 Then Call Abort 'open:',1
Say 'errors: causing error in sqlfetch()...'
If sqlfetch('q1') < 0 Then Call Abort 'fetch:',1
If sqlprepare('q1','select * from RX_EMP') < 0 Then Call Abort 'prepare:'
If sqlfetch('q1') < 0 Then Call Abort 'fetch:',1
If sqldispose('q1') < 0 Then Call Abort 'dispose:'
Say 'errors: causing error with placemarkers...'
If sqlvariable('SUPPORTSPLACEMARKERS') = 0 Then
   Say db 'does not support the use of placemarkers in queries. This test ignored.'
Else
  Do
     rc = sqlvariable('STANDARDPLACEMARKERS',1)
     If sqlprepare('q1','select * from RX_EMP where empid = ?') < 0 Then Call Abort 'prepare:'
     If sqlopen('q1') < 0 Then Call Abort 'open:',1
     If sqlopen('q1','junk') < 0 Then Call Abort 'open:',1
     If sqlopen('q1','junk',10) < 0 Then Call Abort 'open:',1
     If sqldispose('q1') < 0 Then Call Abort 'dispose:'
  End
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
info: Procedure Expose sqlca. sqlconnect. db columnnames_emp columnnames_dept
Say Copies('*',20)
Say 'Testing sqlvariable and sqlgetinfo...'
Say Copies('*',20)
valid_info = 'SUPPORTSTRANSACTIONS SUPPORTSSQLGETDATA SUPPORTSTHREADS DBMSNAME',
             'DBMSVERSION DESCRIBECOLUMNS DATATYPES'
valid_variable = 'SUPPORTSDMLROWCOUNT SUPPORTSPLACEMARKERS',
             'LONGLIMIT AUTOCOMMIT IGNORETRUNCATE NULLSTRINGIN NULLSTRINGOUT',
             'STANDARDPLACEMARKERS DEBUG VERSION ROWLIMIT SAVESQL'
Say 'info: Valid values for sqlvariable()...' valid_variable
Do i = 1 to Words(valid_variable)
   Say Left('      Current value for' Word(valid_variable,i),50) "'"sqlvariable(Word(valid_variable,i))"'"
End
Call connect 'c1'
Say 'info: Valid values for sqlgetinfo()...' valid_info
Do i = 1 to Words(valid_info)
   rc = sqlgetinfo('c1',Word(valid_info,i),'desc.')
   If rc < 0 Then Say '      ERROR:' sqlca.interrm ':' sqlca.sqlerrm
   Else
     Do
       var = Word(valid_info,i)
       Do j = 1 To desc.0
         If j = 1 Then Say Left('      Current value for' var,50) "'"desc.j"'"
         Else Say Copies(' ',50) "'"desc.j"'"
       End
     End
End
Call disconnect 'c1'
Return

/*-----------------------------------------------------------------*/
Abort: Procedure Expose sqlca.
Parse Arg message, kontinue
Say 'Error in' message
If sqlca.intcode = -1 Then
  Do
    Say 'SQLCODE:' sqlca.sqlcode
    Say 'SQLERRM:' sqlca.sqlerrm
    Say 'SQLTEXT:' sqlca.sqltext
    Say 'SQLSTATE:' sqlca.sqlstate
  End
Else
  Do
    Say 'INTCODE:' sqlca.intcode
    Say 'INTERRM:' sqlca.interrm
  End
If kontinue = 1 Then Return
Else
   Do
     Call SqlDropFuncs
     Exit 1
   End

Syntax:
Say 'Syntax error at line:' sigl
Say 'Statement:' Strip( Sourceline( sigl ) )
Call SqlDropFuncs "UNLOAD"
Exit 1
