/***********************************************************************/
/* syb.c - REXX/SQL for Sybase                                         */
/***********************************************************************/
/*
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling 1995-1999.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to:
 *
 *    The Free Software Foundation, Inc.
 *    675 Mass Ave,
 *    Cambridge, MA 02139 USA.
 *
 *
 * If you make modifications to this software that you feel increases
 * it usefulness for the rest of the community, please email the
 * changes, enhancements, bug fixes as well as any and all ideas to 
 * address below.
 * This software is going to be maintained and enhanced as deemed
 * necessary by the community.
 *
 * Mark Hessling  M.Hessling@qut.edu.au  http://www.lightlink.com/hessling/
 *
 * Author:	Mark Hessling 
 *
 *    Purpose:	This module provides a Sybase SQL interface for REXX. It
 *		allows REXX programs to connect to Sybase servers, issue SQL
 *		queries, DDL, DCL & DML statements. Multiple concurrent
 *		connections are supported. Additionally, multiple statements
 *		may be active concurrently against any or all of these
 *		connections. This interface is called "REXX/SQL".
 *
 */

static char RCSid[] = "$Id: syb.c,v 1.3 2002/07/11 07:30:56 mark Exp $";

#include "rxpack.h"

#define INCL_RXSHV	/* Shared variable support */
#define INCL_RXFUNC	/* External functions support */

#define INCL_NOPMAPI	/* Exclude PM API calls to get around clashes of CS_PUBLIC defintions in Sybase and OS/2 */

#include "dbdefine.h"
#include "rexxsql.h"
#include "dbheader.h"
#include "dbtypes.h"

 typedef CS_CONNECTION SYB_CONN_HANDLE;

/*
 * Definition of Sybase fields.  This contains definitions of Sybase
 * columns returned in a result set.
 */

typedef struct 
{
 int         field_type;	/* indicates if the field is a normal or compute field */
 char        *colname;		/* name of column */
 int         coltype;		/* data type of column */
 int         collen;		/* maximum length of data */
 int         scale;		/* scale of data */
 int         prec;		/* precision of data */
 CS_SMALLINT nullok;		/* column nullable ? */
 CS_DATAFMT  result_datafmt;		/* bind area for output data */
 long        rbufl;		/* size of allocated buffer for column data */
 char        *rbuf;		/* pointer to returned column data */
} FLDDSCR;


/*
 * Definition of SQL Work Area (SQLWA).  This contains the Sybase user
 * context area plus additional information required by this interface to
 * control the processing of SQL statements.
 */

typedef struct 
{
 SYB_CONN_HANDLE   *conn_handle;               /* connection handle */
 CS_COMMAND *cmd;              /* command structure for dynamic SQL */
 char *sql_stmt;             /* ptr to buffer to hold SQL statement */
 int  sql_stmt_sz;            /* size of allocated statement buffer */
 int  state;                        /* the state of the transaction */
 int  select;                   /* indicates if statement is SELECT */
 int bind_cnt;                             /* number of bind values */
 int expr_cnt;              /* number of expressions in select list */
 FLDDSCR *fa[MAX_COLS];       /* array of pointers to column dscr's */
 CS_DATAFMT bind_datafmt[MAX_BINDVARS]; /* bind area for bind value */
} SQLWA;


/* 
 * Connection structure. Each connection requires one of these! 
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct 
{
 char            name[MAX_IDENTIFIER+1];            /* Connection name */
 SYB_CONN_HANDLE *conn_handle;                    /* Connection handle */
 void            *dflt_stmt;           /* Pointer to default statement */
 void            *trans_stmt;  /* Pointer to COMMIT/ROLLBACK statement */
 int             num_statements;      /* Number of explicit statements */
 SQLVAL          *db_opt;                     /* SqlGetInfo hash table */
} DBCON;


/* 
 * Statement structure. Each statement requires one of these! 
 * NB! The field; name, MUST be the first entry in the structure.
 */
typedef struct 
{
 char      name[MAX_IDENTIFIER+1];	/* Statement name */
 DBCON     *db;			/* Pointer to connection structure */
 SQLWA     sqlwa;			/* Work area for statement */
} STMT;


/* 
 * Basic REXXSQL environment structure - allocated when 1st connection made! 
 */
typedef struct 
{
 int       num_connections;		/* Number of active connections */
 CS_CONTEXT *cs_context;	/* context pointer */
 DBCON     *current_connection;	/* Pointer to current connection */
 BUCKET    *db_tbl[TBL_CONNECTIONS];	/* Connection hash table */
 BUCKET    *stmt_tbl[TBL_STATEMENTS];/* Statement hash table */
} DBENV;

char *column_attribute[] = 
{
 "NAME", "TYPE", "SIZE", "PRECISION", "SCALE", "NULLABLE",(char*)NULL
};

/*
 * ReadOnly variables
 *
 * ---------------------------------------------------------------------
 * Current version/platform
 */
static RXSTRING RexxSqlVersion;
static char RexxSqlVersionString[100];

/*
 * ---------------------------------------------------------------------
 * Database Name and Version
 */
static RXSTRING RXSDBMSName;
static char DBMSName[100];

static RXSTRING RXSDBMSVer;
static char DBMSVer[50+1];

/* ---------------------------------------------------------------------
 * Error value returned for errors returned by database as opposed to
 * those generated by the interface.
 */
#define DB_ERROR	(-1L)

/* ---------------------------------------------------------------------
 * State values to ensure that certain calls can only be processed in
 * a certain order.
 */
#define REXXSQL_STATE_IDLE      0
#define REXXSQL_STATE_PREPARED  1
#define REXXSQL_STATE_EXECUTED  2
#define REXXSQL_STATE_CLOSED    3

/* Global Function Name - set on entry to every REXX/SQL function */
char FName[40];

/* Place for the Last Database message to be stored */
char LastDBError[(CS_MAX_MSG*2)+1024];

/* 
 * Indicators for whether an error or warning has occurred in the database
 */
static int DBErrorPending=FALSE;

extern ULONG RowLimit;
extern ULONG LongLimit;
extern ULONG SaveSQL;
extern ULONG AutoCommit;
extern ULONG IgnoreTruncate;
extern ULONG StandardPlacemarkers;
extern ULONG SupportsTransactions;
extern ULONG SupportsPlacemarkers;
extern ULONG SupportsDMLRowcount;
extern ULONG SupportsSqlGetData;
extern char DebugFile[MAX_PATH+1];
extern RXSTRING RXSDebugFile;
extern RXSTRING RXSNullStringOut;
extern char NullStringOut[MAX_IDENTIFIER+1];
extern RXSTRING RXSNullStringIn;
extern char NullStringIn[MAX_IDENTIFIER+1];

SQLVAL *opt_tbl = NULL;

#ifdef HAVE_PROTO
static void *SetDescribeColumns(DBCON *);
static void *SetDatatypes(DBCON *);
static void *SetVersion(void *);
static void *SetDebugFile(void *);
static void *SetNullStringIn(void *);
static void *SetNullStringOut(void *);
static void *SetDBMSName(DBCON *);
static void *SetDBMSVer(DBCON *);
static void *SetSupportsSqlGetData(DBCON *);
static void *SetSupportsTransactions(DBCON *);
static int ValidateDataType(char *, int, DBCON *);
#else
static void *SetDescribeColumns();
static void *SetDatatypes();
static void *SetVersion();
static void *SetDebugFile();
static void *SetNullStringIn();
static void *SetNullStringOut();
static void *SetDBMSName();
static void *SetDBMSVer();
static void *SetSupportsSqlGetData();
static void *SetSupportsTransactions();
static int ValidateDataType();
#endif

/* ---------------------------------------------------------------------
 * The following table defines those values that can be used with the
 * SQLGetInfo() and SQLSetInfo() functions.
 */
/* name            settable  type         dyn/conn reqd                     maxlen  value func */
SQLVAL sqlvariable_vars[] =
{
 {NULL,NULL,"DEBUG",                1, TYPE_INT,     OPT_STATIC ,0, NULL,   SQLVAL_DEBUG},
 {NULL,NULL,"DEBUGFILE",            1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DEBUGFILE},
 {NULL,NULL,"ROWLIMIT",             1, TYPE_INT,     OPT_STATIC ,0, (void*)&RowLimit,0},
 {NULL,NULL,"LONGLIMIT",            1, TYPE_INT,     OPT_STATIC ,0, (void*)&LongLimit,0},
 {NULL,NULL,"SAVESQL",              1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&SaveSQL,0},
 {NULL,NULL,"AUTOCOMMIT",           1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&AutoCommit,0},
 {NULL,NULL,"IGNORETRUNCATE",       1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&IgnoreTruncate,0},
 {NULL,NULL,"NULLSTRINGIN",         1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_NULLSTRINGIN},
 {NULL,NULL,"NULLSTRINGOUT",        1, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_NULLSTRINGOUT},
 {NULL,NULL,"STANDARDPLACEMARKERS", 1, TYPE_BOOL,    OPT_STATIC ,0, (void*)&StandardPlacemarkers,0},
 {NULL,NULL,"SUPPORTSDMLROWCOUNT",  0, TYPE_BOOL,    OPT_STATIC ,0, (void*)&SupportsDMLRowcount,0},
 {NULL,NULL,"SUPPORTSPLACEMARKERS", 0, TYPE_BOOL,    OPT_STATIC ,0, (void*)&SupportsPlacemarkers,0},
 {NULL,NULL,"VERSION",              0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_VERSION},
 {NULL,NULL,"",                     0, 0,            0          ,0, NULL,0},
};

SQLVAL sqlgetinfo_vars[] =
{
 {NULL,NULL,"SUPPORTSTRANSACTIONS", 0, TYPE_BOOL,    OPT_STATIC ,0, NULL,   SQLVAL_SUPPORTSTRANSACTIONS},
 {NULL,NULL,"SUPPORTSSQLGETDATA",   0, TYPE_BOOL,    OPT_STATIC ,0, NULL,   SQLVAL_SUPPORTSSQLGETDATA},
 {NULL,NULL,"DESCRIBECOLUMNS",      0, TYPE_ARRAY,   OPT_DYNAMIC,0, NULL,   SQLVAL_DESCRIBECOLUMNS},
 {NULL,NULL,"DATATYPES",            0, TYPE_DATATYPE,OPT_DYNAMIC,0, NULL,   SQLVAL_DATATYPES},
 {NULL,NULL,"DBMSNAME",             0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DBMSNAME},
 {NULL,NULL,"DBMSVERSION",          0, TYPE_STRING,  OPT_STATIC ,0, NULL,   SQLVAL_DBMSVERSION},
 {NULL,NULL,"",                     0, 0,            0          ,0, NULL,   0},
};

/* ---------------------------------------------------------------------
 * Pointer to REXXSQL environment - initially unallocated!
 * Only one object of this type is required and this object is created
 * the first time a connection is made. This object is released whenever
 * the last connection is released or upon exit.
 */
static DBENV *DbEnv = (DBENV*)NULL;

/* ---------------------------------------------------------------------
 * These global variables hold the result of the last function call.
 */
RXSQL_SQLCODE_TYPE  SQLCA_SqlCode  = -1L;	/* Force a clear on startup */
RXSQL_ROWCOUNT_TYPE SQLCA_RowCount = -1L;	/* Force a clear on startup */
long SQLCA_IntCode                 = -1L;	/* Force a clear on startup */
RXSQL_SQLSTATE_TYPE SQLCA_SqlState[SQL_SQLSTATE_SIZE+1]; /* UNUSED */
ULONG    SQLCA_ComputeCount = -1L;	/* Force a clear on startup */

CS_RETCODE CS_PUBLIC sybclimsg_handler (
	CS_CONTEXT *,SYB_CONN_HANDLE *,CS_CLIENTMSG *);
CS_RETCODE CS_PUBLIC sybsrvmsg_handler (
	CS_CONTEXT *,SYB_CONN_HANDLE *,CS_SERVERMSG *);
CS_RETCODE CS_PUBLIC sybcsmsg_handler (
	CS_CONTEXT *,CS_CLIENTMSG *);

/*-----------------------------------------------------------------------------
 * Fetch the DB error and put into REXX "SQLCA." compound variable.
 *----------------------------------------------------------------------------*/
static void SetDBError

#ifdef HAVE_PROTO
    (SQLWA *swa)
#else
    (swa)
    SQLWA     *swa;
#endif

{
 char    *txt=NULL;

 /* Get the statement text */
 txt = (swa == (SQLWA*)NULL) ? "" : (swa->sql_stmt) ? swa->sql_stmt : "";

 /* Set SQLCA. variable */
 SetSQLCA(SQLCA_SqlCode, SQLCA_SqlState, LastDBError, txt);
 /* Clear the error flag set by syberr_message() function */
 DBErrorPending = FALSE;
 return;
}


/*-----------------------------------------------------------------------------
 * Allocate a DBENV object. Only one database environment is allocated.
 * This structure is allocated when the first connection is made and deallocated
 * when the last connection is released.
 * Note that statement names are global and hence are defined in this structure
 * and not in the connection structure as would be the case if they were unique
 * to a connection!
 *----------------------------------------------------------------------------*/
static DBENV *AllocDbEnvironment

#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif

{
 DBENV  *dbenv=NULL;
 int    i=0;

 if ((dbenv = (DBENV*)malloc(sizeof(DBENV))) == (DBENV*)NULL)
    return (DBENV*)NULL;
 dbenv->num_connections = 0;
 dbenv->current_connection = (DBCON*)NULL;
 for (i = 0; i < TBL_CONNECTIONS; i++)
     dbenv->db_tbl[i] = (BUCKET*)NULL;
 for (i = 0; i < TBL_STATEMENTS; i++)
     dbenv->stmt_tbl[i] = (BUCKET*)NULL;
 return dbenv;
}



/*-----------------------------------------------------------------------------
 * Allocate a DBCON object. One of these is required for each database
 * connection. This structure is allocated when the connection is made and
 * deallocated when the connection is released.
 *----------------------------------------------------------------------------*/
static DBCON *AllocConnection

#ifdef HAVE_PROTO
    (char *name)
#else
    (name)
    char *name;
#endif

{
 DBCON  *db=NULL;

 if ((db = (DBCON*)NewObject(sizeof(DBCON))) == (DBCON*)NULL)
     return (DBCON*)NULL;
 (void)strncpy(db->name, name, MAX_IDENTIFIER);
 db->dflt_stmt = (void*)NULL;
 db->trans_stmt = (void*)NULL;
 db->num_statements = 0;
 return db;
}



/*-----------------------------------------------------------------------------
 * Open a database connection. This requires allocating a connection object
 * and making the connection to Sybase.
 *----------------------------------------------------------------------------*/
static int OpenConnection

#ifdef HAVE_PROTO
    (PSZ cnctname, PSZ username, PSZ password, PSZ dbName, DBCON **new_db)
#else
    (cnctname,username,password,dbName,new_db)
    PSZ     cnctname;
    PSZ     username;
    PSZ     password;
    PSZ     dbName;
    DBCON   **new_db;
#endif

{
 DBCON   *db=NULL;
 int     rc=0,i=0;
 void    *(*func)()=NULL;
 SYB_CONN_HANDLE *conn_handle=NULL;
 char      *tmp_dbName=NULL;
 SQLVAL  *curr=NULL;
 void    *result=NULL;

 if ((db = AllocConnection(cnctname)) == (DBCON*)NULL)
     return(SetIntError(__FILE__,__LINE__,10, "out of memory"));

 if (ct_con_alloc(DbEnv->cs_context, &db->conn_handle) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 if (ct_con_props(db->conn_handle, CS_SET, CS_USERNAME, (username==NULL)?"":username, (username==NULL)?0:strlen(username), NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 if (ct_con_props(db->conn_handle, CS_SET, CS_PASSWORD, (password==NULL)?"":password, (password==NULL)?0:strlen(password), NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 if (ct_con_props(db->conn_handle, CS_SET, CS_APPNAME, DLLNAME, strlen(DLLNAME), NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 if (ct_connect(db->conn_handle, (dbName==NULL)?"":dbName, (dbName==NULL)?0:strlen(dbName)) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
#if 0
 {
  CS_BOOL res;
  ct_capability(db->conn_handle,CS_GET,CS_CAP_REQUEST,CS_PROTO_DYNAMIC,&res);
 if (RxGetRunFlags() == 99)
    fprintf(stderr,"************** CS_PROTO_DYNAMIC: %s **************\n",
          (res==CS_TRUE)?"TRUE":"FALSE");
 }
#endif
#ifdef THIS_FAILS_UNDER_OS2
 {
  CS_BOOL res=CS_FALSE;
 if (ct_options(db->conn_handle,CS_GET,CS_OPT_NOCOUNT,&res,CS_UNUSED,NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 if (RxGetRunFlags() == 99)
    fprintf(stderr,"************** CS_OPT_NOCOUNT: %s **************\n",
          (res==CS_TRUE)?"TRUE":"FALSE");
 res = (res==CS_TRUE)?CS_FALSE:CS_TRUE;
 if (ct_options(db->conn_handle,CS_SET,CS_OPT_NOCOUNT,&res,CS_UNUSED,NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(NULL);
    return(DB_ERROR);
   }
 }
#endif


 /*
  * Setup any connection-specific variable information
  */
 for (i=0;strlen(sqlgetinfo_vars[i].name)!=0;i++)
   {
    if (sqlgetinfo_vars[i].value)
       result = sqlgetinfo_vars[i].value;
    else
       result = GetSqlVariableValue(sqlgetinfo_vars[i].valtype,(void*)db);
    if ((curr = InstallSQLVariable(
                &rc,
                sqlgetinfo_vars[i].name,
                db->db_opt,
                sqlgetinfo_vars[i].user_update, 
                sqlgetinfo_vars[i].dtype, 
                0, 
                sqlgetinfo_vars[i].option,
                result,
                sqlgetinfo_vars[i].valtype)) == NULL)
      {
       return(rc);
      }
    if (db->db_opt == NULL)
       db->db_opt = curr;
   }
 *new_db = db;
 return 0;
}


/*-----------------------------------------------------------------------------
 * Allocate a STMT object. One of these is required for each statement
 * including the default statement for a connection. An instance of this object
 * is allocated when (i) a statement is prepared & (ii) the first time
 * SQLCOMMAND() is called for a connection (ie. the default statement is used).
 *----------------------------------------------------------------------------*/
static STMT *AllocStatement

#ifdef HAVE_PROTO
    (char *name, DBCON *db)
#else
    (name, db)
    char  *name;
    DBCON *db;
#endif

{
 STMT    *stmt=NULL;
 SQLWA   *swa=NULL;
 int	    i=0;


 if ((stmt = (STMT*)NewObject(sizeof(STMT))) == (STMT*)NULL)
     return (STMT*)NULL;
 stmt->db = db;
 (void)strncpy(stmt->name, name, MAX_IDENTIFIER);

 /* Initialise SQL Work Area */
 swa = SWA(stmt);
 swa->expr_cnt = 0;
 swa->sql_stmt = (char*)NULL;
 swa->sql_stmt_sz = 0;
 swa->conn_handle = db->conn_handle;
 swa->cmd = NULL;
 swa->bind_cnt = 0;
 swa->state = REXXSQL_STATE_IDLE;

 /* Set pointer for each column descriptor to NULL (unused) */
 for (i = 0; i < MAX_COLS; i++)
 	swa->fa[i] = (FLDDSCR*)NULL;

 return stmt;
}




/*-----------------------------------------------------------------------------
 * Open a statement. This allocates a statement.
 *----------------------------------------------------------------------------*/
static int OpenStatement

#ifdef HAVE_PROTO
    (char *name, DBCON *db, STMT **new_stmt)
#else
    (name, db, new_stmt)
    char  *name;
    DBCON *db;
    STMT  **new_stmt;

#endif

{
 int	    rc=0;
 STMT    *stmt=NULL;
 SQLWA   *swa=NULL;

 
 if ((stmt = AllocStatement(name, db)) == (STMT*)NULL)
     return(SetIntError(__FILE__,__LINE__,10, "out of memory"));

 swa = SWA(stmt);
 if (ct_cmd_alloc(db->conn_handle,&swa->cmd) != CS_SUCCEED)
    return(DB_ERROR);
 *new_stmt = stmt;
 return (rc==0) ? 0 : DB_ERROR;
}




/*-----------------------------------------------------------------------------
 * Disposes a SQL statement. This closes the database cursor and frees the
 * statement structure and all resources associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseStatement

#ifdef HAVE_PROTO
    (STMT *stmt)
#else
    (stmt)
    STMT *stmt;
#endif

{
 SQLWA    *swa = SWA(stmt);
 int	     rc=0;


 /* Close database cursor */
 if (CTX(swa))
   {
    if (ct_cmd_drop(swa->cmd) != CS_SUCCEED)
       return(DB_ERROR);
    swa->cmd = NULL;
   }
 
 /* Free sql statement buffer (if any) */
 if (swa->sql_stmt)
   {
    free(swa->sql_stmt);
    swa->sql_stmt = NULL;
   }

 FreeObject(stmt);

 return (rc==0) ? 0 : DB_ERROR;
}





/*-----------------------------------------------------------------------------
 * Release n database connection. This closes any open statements associated
 * with the connection, closes the connection and frees all resources
 * associated with it.
 *----------------------------------------------------------------------------*/
static int ReleaseConnection

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif

{
 int    i=0, rc=0, last_error=0;
 STMT   *stmt=NULL, *t=NULL;

 /* Remove the Connection structure from the hash structures etc. */
 (void)RemoveObject(db);

 /* Decrement the count of active connections. */
 DbEnv->num_connections--;

 /* Dispose all active statements for this connection. */
 for (i = 0; db->num_statements && i < TBL_STATEMENTS; i++) 
   {
    stmt = (STMT*)FirstObject(i, DbEnv->stmt_tbl);
    while (stmt && db->num_statements) 
      {
       t = (STMT*)NextObject(stmt);
       if (stmt->db == db) 
         {
          RemoveObject(stmt);
          last_error = (rc = ReleaseStatement(stmt)) ? rc : last_error;
          db->num_statements--;
         }
       stmt = t;
      }
   }

 /* 
  * Dispose the default statement (if any). 
  */
 if (db->dflt_stmt)
    last_error = (rc = ReleaseStatement((STMT*)(db->dflt_stmt))) ? rc : last_error;
 /* 
  * Dispose the COMMIT/ROLLBACK statement (if any).
  */
 if (!last_error
 &&  db->trans_stmt)
    last_error = (rc = ReleaseStatement((STMT*)(db->trans_stmt))) ? rc : last_error;

 /* Disconnect from database */
 if (ct_close(db->conn_handle,CS_UNUSED) != CS_SUCCEED)
   {
    ct_close(db->conn_handle, CS_FORCE_EXIT);
   }

 /* Free the connection structure */
 FreeObject(db);

 return (last_error);
}



/*-----------------------------------------------------------------------------
 * Release the Sybase environment. This releases all active connections
 * (if any).
 *----------------------------------------------------------------------------*/
int ReleaseDbEnvironment

#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif

{
 int    i=0, rc=0, last_error=0;
 DBCON  *db=NULL, *t=NULL;

 /* Ensure there is an environment to release! */
 if (DbEnv == (DBENV*)NULL)
     return 0;

 /* Release all connections. */
 for (i = 0; DbEnv->num_connections && i < TBL_CONNECTIONS; i++) 
   {
    db = (DBCON*)FirstObject(i, DbEnv->db_tbl);
    while (db && DbEnv->num_connections) 
      {
       t = (DBCON*)NextObject(db);
       last_error = (rc = ReleaseConnection(db)) ? rc : last_error;
       db = t;
      }
   }

 /* 
  * Clean up all remaining structures
  */
 if (ct_exit(DbEnv->cs_context, CS_UNUSED) != CS_SUCCEED)
   {
    ct_exit(DbEnv->cs_context, CS_FORCE_EXIT);
   }
 (CS_VOID) cs_ctx_drop(DbEnv->cs_context);

 /* 
  * Free the DB environment 
  */
 free(DbEnv);
 DbEnv = (DBENV*)NULL;
 return (last_error);
}


/*-----------------------------------------------------------------------------
 * SYNOPSIS : SQLCONNECT( [connection-name] [,username] [,password] [,server name])
 *
 * ARGUMENTS: 
 *            0 - connection_name (optional)
 *            1 - username (optional)
 *            2 - password (optional)
 *            3 - server name (optional)
 *
 * RETURNS  : 0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLCONNECT

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 char	*dbName=NULL;
 char	*username=NULL;
 char	*password=NULL;
 char	cnctname[MAX_IDENTIFIER+1];
 int	rc=0;
 char        tmp[128];
 DBCON       *db=NULL;

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc > 5) return 1;

 /* 
  * Allocate a DB environment if none exists! 
  */
 if (DbEnv == (DBENV*)NULL) 
   {
    if ((DbEnv = AllocDbEnvironment()) == (DBENV*)NULL)
       return ReturnError(retstr, 10, "out of memory.");
   }

 /*
  * Get the name of the connection (default if not specified).
  */
 if (argc > 0
 &&  RXSTRLEN(argv[0]))
   {
    if ((rc = MkIdentifier(argv[0], cnctname, sizeof(cnctname))))
       return RxReturnNumber(retstr, rc);
   }
 else 
   {
    (void)strcpy(cnctname, DEFAULT_CONNECTION);
   }

 /* 
  * Make sure there is no existing connection with the same name 
  */
 if (FindObject(cnctname, DbEnv->db_tbl, TBL_CONNECTIONS)) 
   {
    (void)sprintf(tmp, "connection already open with name \"%s\".", cnctname);
    return ReturnError(retstr, 20, tmp);
   }

 /*
  * Allocate space for username if supplied...
  */
 if (argc > 1
 &&  RXSTRLEN(argv[1]))
   {
    if ((username = AllocString(RXSTRPTR(argv[1]),RXSTRLEN(argv[1]))) == NULL)
       return ReturnError(retstr, 10, "out of memory.");
    MkAsciz(username, RXSTRLEN(argv[1])+1, RXSTRPTR(argv[1]), RXSTRLEN(argv[1]));
   }

 /*
  * Allocate space for password if supplied...
  */
 if (argc > 2
 &&  RXSTRLEN(argv[2]))
   {
    if ((password= AllocString(RXSTRPTR(argv[2]),RXSTRLEN(argv[2]))) == NULL)
       return ReturnError(retstr, 10, "out of memory.");
    MkAsciz(password,RXSTRLEN(argv[2])+1, RXSTRPTR(argv[2]), RXSTRLEN(argv[2]));
   }

 /*
  * Allocate space for server name if supplied...
  */
 if (argc > 3 
 &&  RXSTRLEN(argv[3]))
   {
    if ((dbName = AllocString(RXSTRPTR(argv[3]),RXSTRLEN(argv[3]))) == NULL)
       return ReturnError(retstr, 10, "out of memory.");
    MkAsciz(dbName, RXSTRLEN(argv[3])+1, RXSTRPTR(argv[3]), RXSTRLEN(argv[3]));
   }

 /* 
  * Open a new connection for the given connect string. 
  */
 if ((rc = OpenConnection(cnctname, username, password, dbName, &db)))
   {
    if (dbName) free(dbName);
    if (username) free(username);
    if (password) free(password);
    return RxReturnNumber(retstr, (long)rc);
   }
 if (dbName) free(dbName);
 if (username) free(username);
 if (password) free(password);

 DbEnv->num_connections++;
 DbEnv->current_connection = db;
 (void)InsertObject(db, DbEnv->db_tbl, TBL_CONNECTIONS);

 return RxReturnNumber(retstr, 0L);
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISCONNECT( [connection-name ] )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLDISCONNECT

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int		rc = 0;
 char        dbname[MAX_IDENTIFIER+1];
 DBCON       *db=NULL;
 char        tmp[128];


 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc > 1) return 1;

 if (DbEnv == (DBENV*)NULL)
     return RxReturnNumber(retstr, 0L);

 if (argc && RXSTRLEN(argv[0])) 
   {
    /* A connection has been named */
    if ((rc = MkIdentifier(argv[0], dbname, sizeof(dbname))))
       return RxReturnNumber(retstr, rc);

    /* Make sure the named connection exists. */
    if ((db = FindObject(dbname, DbEnv->db_tbl, TBL_CONNECTIONS))  == (DBCON*)NULL) 
      {
       (void)sprintf(tmp,"connection \"%s\" is not open.",dbname);
       return ReturnError(retstr, 21, tmp);
      }
   }
 else 
   {
    if (DbEnv->current_connection)
       db = DbEnv->current_connection;
    else
       return ReturnError(retstr, 25, "no connection is current");
   }

 /*
  * If terminating the current connection then make it so there is
  * no current connection!
  */
 if (db == DbEnv->current_connection)
     DbEnv->current_connection = (DBCON*)NULL;

 /* Do the disconnection */
 rc = ReleaseConnection(db);

 /* Free the environment if zero connections remaining */
 /* Can't do this under Sybase */
 /*
 if (DbEnv->num_connections == 0) 
   {
    free(DbEnv);
    DbEnv = (DBENV*)NULL;
   }
 */

 return RxReturnNumber(retstr, (long)rc);
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDEFAULT( [connection-name ] )
 *
 * RETURNS :  When called with 0 args : 0-success, <0-error.
 *         :  When called with 1 arg  : Name of current connection else "".
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLDEFAULT

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 char        dbname[MAX_IDENTIFIER+1];
 DBCON       *db=NULL;
 char        tmp[128];
 int rc=0;

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc > 1) return 1;

 if (argc && RXSTRLEN(argv[0])) 
   {
    /* Get the normalised name of the connection. */
    if ((rc = MkIdentifier(argv[0], dbname, sizeof(dbname))))
       return RxReturnNumber(retstr, rc);

    /* Make sure we have an environment! */
    if (DbEnv == (DBENV*)NULL)
       return ReturnError(retstr, 22, "no connections open.");

    /* Make sure the Connection Name is a valid one! */
    if ((db = FindObject(dbname, DbEnv->db_tbl, TBL_CONNECTIONS)) == (DBCON*)NULL)
      {
       (void)sprintf(tmp,"connection \"%s\" is not open.", dbname);
       return ReturnError(retstr, 21, tmp);
      }

    /* 
     * Make connection the default one! 
     */
    DbEnv->current_connection = db;

    /*
     * Change databases
     */
    return RxReturnNumber(retstr, (rc==0)?0:DB_ERROR);
   }
 else 
    if (DbEnv && DbEnv->current_connection) 
      {
       return RxReturnString(retstr, DbEnv->current_connection->name);
      }
 else 
   {
    return RxReturnString(retstr, "");
   }
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  Called by SQLCOMMIT( ) &  SQLROLLBACK( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLTRANSACT

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG0_TYPE		stck,RFH_ARG4_TYPE	retstr,int commit)
#else
    (name, argc, argv, stck, retstr, commit)
    PFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
    int commit;
#endif
{ 
 int		rc = 0;
 DBCON       *db=NULL;
 STMT        *stmt=NULL;
 SQLWA       *swa=NULL;
 CS_INT      retcode=0;
 CS_INT      result_type=0;


 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc > 1) return 1;

 if (DbEnv == (DBENV*)NULL)
    return(SetIntError(__FILE__,__LINE__,22, "no connections open"));

 if (DbEnv->current_connection)
    db = DbEnv->current_connection;
 else
    return(SetIntError(__FILE__,__LINE__,25, "no connection is current"));

fprintf(stderr,"%d\n",__LINE__);
 /* 
  * If no statement for COMMIT/ROLLBACK, then create it!
  */
 if ((stmt = (STMT*)(db->trans_stmt)) == (STMT*)NULL)
   {
fprintf(stderr,"%d\n",__LINE__);
    /* 
     * Open a statement for the statement. 
     */
    if ((rc = OpenStatement(TRANS_STATEMENT, db, &stmt)))
       return RxReturnNumber(retstr, rc);
fprintf(stderr,"%d\n",__LINE__);
    db->trans_stmt = (void*)stmt;
   }

fprintf(stderr,"%d\n",__LINE__);
 swa = SWA(stmt);

 if (ct_command(swa->cmd,CS_LANG_CMD,(commit)?"COMMIT":"ROLLBACK",CS_NULLTERM,CS_UNUSED) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"%d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"%d\n",__LINE__);
 if (ct_send(swa->cmd) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"%d\n",__LINE__);
    SetDBError(SWA(stmt));
    rc = DB_ERROR;
   }
fprintf(stderr,"%d\n",__LINE__);
 while ((retcode = ct_results(swa->cmd, &result_type)) == CS_SUCCEED)
   {
fprintf(stderr,"%d\n",__LINE__);
    if (DBErrorPending)
      {
fprintf(stderr,"%d\n",__LINE__);
       SetDBError(SWA(stmt));
       return RxReturnNumber(retstr, DB_ERROR);
      }
fprintf(stderr,"%d\n",__LINE__);
    switch(result_type)
      {
       case CS_ROW_RESULT:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99)
            fprintf(stderr, "ct_dynamic(SQLTRANS) row results\n");
            break;
       case CS_DESCRIBE_RESULT:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) describe results\n");
            break;
       case CS_CURSOR_RESULT:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) cursor results\n");
            break;
       case CS_CMD_SUCCEED:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) no addition results\n");
            break;
       case CS_CMD_DONE:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) done with 1 result set\n");
            break;
       case CS_CMD_FAIL:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) result set failure\n");
            break;
       default:
fprintf(stderr,"%d\n",__LINE__);
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(SQLTRANS) unexpected result type (%d)\n",result_type);
            break;
      }
   }
fprintf(stderr,"%d\n",__LINE__);
 switch (retcode)
   {
    case CS_END_RESULTS:
fprintf(stderr,"%d\n",__LINE__);
         break;
    case CS_FAIL:
fprintf(stderr,"%d\n",__LINE__);
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "ct_results for (SQLTRANS) failed\n");
         break;
    default:
fprintf(stderr,"%d\n",__LINE__);
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "ct_results for (SQLTRANS) unexpected return code (%d)\n",retcode);
         return (retcode);
         break;
   }
fprintf(stderr,"%d\n",__LINE__);
 return(0L);
}


/*-----------------------------------------------------------------------------
 * Binds all arguments (by number) to the parsed (prepared) SQL statement.
 *----------------------------------------------------------------------------*/
static int BindValues

#ifdef HAVE_PROTO
    (STMT *stmt,char *stem_name,int describe,ULONG argc,RXSTRING argv[])
#else
    (stmt, stem_name, describe, argc, argv)
    STMT          *stmt;
    char          *stem_name;
    int           describe;
    ULONG         argc;
    RXSTRING      argv[];
#endif
{
 int          i=0;
 CS_INT       bindlen=0;
 CS_VOID      *bindaddr=NULL;
 CS_SMALLINT  indp=0;
 char         tmp[128];
 SQLWA        *swa= SWA(stmt);
 CS_INT       num_bind_vars=0;
 CS_INT       result_type=0;
 CS_INT       retcode=0;

 if (describe)
   {
    /*
     * Bind all variables (if any) to placeholders in SQL statement. It is
     * assumed that the variables are static for the life of the SQL statement
     * i.e. their addresses remain fixed.
     */
    if (ct_dynamic(swa->cmd, CS_DESCRIBE_INPUT, stem_name, CS_NULLTERM, NULL, CS_UNUSED) != CS_SUCCEED
    ||  DBErrorPending)
      {
       SetDBError(SWA(stmt));
       return(DB_ERROR);
      }
    if (ct_send(swa->cmd) != CS_SUCCEED
    ||  DBErrorPending)
      {
       SetDBError(SWA(stmt));
       return(DB_ERROR);
      }
    while ((retcode = ct_results(swa->cmd, &result_type)) == CS_SUCCEED)
      {
       if (DBErrorPending)
         {
          SetDBError(SWA(stmt));
          return(DB_ERROR);
         }
       switch(result_type)
         {
          case CS_ROW_RESULT:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) row results\n");
               break;
          case CS_DESCRIBE_RESULT:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) describe results\n");
               if (ct_res_info(swa->cmd,CS_NUMDATA,&num_bind_vars,CS_UNUSED,NULL) != CS_SUCCEED
               ||  DBErrorPending)
                 {
                  SetDBError(swa);
                  return(DB_ERROR);
                 }
          if (RxGetRunFlags() == 99) 
              {
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) num_bind_vars:%d\n",num_bind_vars);
#if defined(__OS2__)
               num_bind_vars = argc;
#endif
              }
   
               /*
                * If the number of bind variables passed is not equal to the number
                * obtained from the parsed statement, error...
                */
               if (argc != num_bind_vars)
                 {
                  (void)sprintf(tmp, "%d bind values passed. %d expected", argc, num_bind_vars);
                  return(SetIntError(__FILE__,__LINE__,61, tmp));
                 }
              
#if 0
               for (i=0;i<num_bind_vars && i<MAX_BINDVARS;i++)
                 {
                  if (memcmp(RXSTRPTR(argv[i]),NullStringIn,RXSTRLEN(argv[i])) == 0)
                    {
                     /* indicate a NULL value */
                     bindaddr = (CS_VOID *)NULL;
                     bindlen = 0;
                     indp = (-1);
                    }
                  else 
                    {
                     bindaddr = (CS_VOID *)RXSTRPTR(argv[i]);
                     bindlen = (CS_INT)RXSTRLEN(argv[i]);
                     indp = 0;
                    }
                  if (ct_describe(swa->cmd, i+1, &(swa->bind_datafmt[i])) != CS_SUCCEED)
                    {
                     SetDBError(swa);
                     return(DB_ERROR);
                    }
                 }
#endif
              
               /* save the new bind count */
               swa->bind_cnt = num_bind_vars;
               break;
          case CS_CURSOR_RESULT:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) cursor results\n");
               break;
          case CS_CMD_SUCCEED:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) no additional results\n");
               break;
          case CS_CMD_DONE:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) done with 1 result set\n");
               break;
          case CS_CMD_FAIL:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) result set failure: %d <%s>\n",DBErrorPending,LastDBError);
               break;
          case CS_ROWFMT_RESULT:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "ct_dynamic(DESCRIBE_INPUT) rowfmt results\n");
               break;
          default:
          if (RxGetRunFlags() == 99) 
               fprintf(stderr, "\nl4_exec_dyn: unexpected result type (%d)",result_type);
               break;
         }
      }
    switch (retcode)
      {
       case CS_END_RESULTS:
            break;
       case CS_FAIL:
       if (RxGetRunFlags() == 99)
            fprintf(stderr, "\nl4_exec_dyn: ct_results() failed");
            break;
       default:
       if (RxGetRunFlags() == 99)
            fprintf(stderr, "\nl4_exec_dyn: ct_results() unexpected return code");
            return (retcode);
            break;
      }
   }
 else
   {
    for (i=0;i<swa->bind_cnt;i++)
      {
       if (memcmp(RXSTRPTR(argv[i]),NullStringIn,RXSTRLEN(argv[i])) == 0)
         {
          /* indicate a NULL value */
          bindaddr = (CS_VOID *)NULL;
          bindlen = 0;
          indp = (-1);
         }
       else 
         {
          bindaddr = (CS_VOID *)RXSTRPTR(argv[i]);
          bindlen = (CS_INT)RXSTRLEN(argv[i]);
          indp = 0;
         }
   
       swa->bind_datafmt[i].status = CS_INPUTVALUE;
       swa->bind_datafmt[i].datatype = CS_CHAR_TYPE;
       
       if (ct_param(swa->cmd, &(swa->bind_datafmt[i]), bindaddr, bindlen, indp) != CS_SUCCEED)
         {
          SetDBError(swa);
          return(DB_ERROR);
         }
      }
   }
 return (0);
}

/*-----------------------------------------------------------------------------
 * Get a column expression descriptor.  Assumes the index is valid!
 *----------------------------------------------------------------------------*/
static FLDDSCR *GetFldDscr

#ifdef HAVE_PROTO
    (SQLWA *swa,int i)
#else
    (swa, i)
    SQLWA   *swa;
    int	    i;
#endif
{
 FLDDSCR *fd=NULL;

 if ((fd = swa->fa[i]) == (FLDDSCR*)NULL) 
   {
    if ((fd = (swa->fa[i] = (FLDDSCR*)malloc(sizeof(FLDDSCR)))) == (FLDDSCR*)NULL) 
      {
       return (FLDDSCR*)NULL;
      }
    fd->colname = (char*)NULL;
    fd->collen = 0;
    fd->rbuf = (char*)NULL;
    fd->rbufl = 0;
    fd->coltype = 0;
    fd->field_type = 0;
    fd->prec = 0;
    fd->scale = 0;
    fd->nullok = 0;
   }
 return fd;
}

#define MAX_CHAR_BUF 1024

static int CalculateDisplayLength

#ifdef HAVE_PROTO
    (CS_DATAFMT *column)
#else
    (column)
    CS_DATAFMT *column;
#endif
{
	CS_INT		len;

	switch ((int) column->datatype)
	{
		case CS_CHAR_TYPE:
		case CS_VARCHAR_TYPE:
		case CS_TEXT_TYPE:
		case CS_IMAGE_TYPE:
			len = min(column->maxlength, MAX_CHAR_BUF);
			break;

		case CS_BINARY_TYPE:
		case CS_VARBINARY_TYPE:
			len = min((2 * column->maxlength) + 2, MAX_CHAR_BUF);
			break;

		case CS_BIT_TYPE:
		case CS_TINYINT_TYPE:
			len = 3;
			break;

		case CS_SMALLINT_TYPE:
			len = 6;
			break;

		case CS_INT_TYPE:
			len = 11;
			break;

		case CS_REAL_TYPE:
		case CS_FLOAT_TYPE:
			len = 20;
			break;

		case CS_MONEY_TYPE:
		case CS_MONEY4_TYPE:
			len = 24;
			break;

		case CS_DATETIME_TYPE:
		case CS_DATETIME4_TYPE:
			len = 30;
			break;

		case CS_NUMERIC_TYPE:
		case CS_DECIMAL_TYPE:
			len = (CS_MAX_PREC + 2);
			break;

		default:
			len = 12;
			break;
	}

	return max(strlen(column->name) + 1, len);
}

/*-----------------------------------------------------------------------------
 * Describes columns (expressions) and defines the output buffers for each
 * column for the select statement in nominated cursor.
 * Returns the number of expressions in the select statement.
 *----------------------------------------------------------------------------*/
static int DefineExpressions

#ifdef HAVE_PROTO
    (STMT *stmt, char *stem_name)
#else
    (stmt,stem_name)
    STMT     *stmt;
    char     *stem_name;
#endif
{
 SQLWA        *swa= SWA(stmt);
 FLDDSCR      *fd=NULL;
 int          i=0;
 char         tmp[128];
 SYB_CONN_HANDLE *conn_handle=NULL;
 char         *tmp_colname=NULL;
 CS_INT       num_expr_vars=0;
 CS_INT       result_type=0;
 CS_RETCODE   retcode=0;

 if (swa->state != REXXSQL_STATE_EXECUTED)
   {
    (void)sprintf(tmp,"statement \"%s\" has not been OPENed or EXECUTEd", stmt->name);
    return(SetIntError(__FILE__,__LINE__,26, tmp));
   }
 conn_handle = swa->conn_handle;
 if (ct_res_info(swa->cmd,CS_NUMDATA,&num_expr_vars,CS_UNUSED,NULL) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(swa);
    return(DB_ERROR);
   }
 if (RxGetRunFlags() == 99) 
    fprintf(stderr, "in DefineExpressions(): %d\n",num_expr_vars);

 swa->expr_cnt = num_expr_vars;

 /* 
  * Describe & define buffer for each expression in the SELECT statement 
  */
 for (i = 0; i < swa->expr_cnt ; i++)
   {
    /* 
     * Allocate a new field descriptor 
     */
    if ((fd = GetFldDscr(swa, i)) == (FLDDSCR*)NULL)
       return(SetIntError(__FILE__,__LINE__,10, "out of memory"));
    /* 
     * Get attributes for each result column
     */
    if (ct_describe(swa->cmd, i+1, &fd->result_datafmt) != CS_SUCCEED)
       return DB_ERROR;

    fd->collen = fd->result_datafmt.maxlength;
    if ((fd->colname = (char*)malloc(1+fd->result_datafmt.namelen)) == (char*)NULL)
       return(SetIntError(__FILE__,__LINE__,10, "out of memory"));
    if (fd->result_datafmt.namelen == 0)
       strcpy(fd->colname,"");
    else
       strcpy(fd->colname,fd->result_datafmt.name);
    fd->coltype = fd->result_datafmt.datatype;
    fd->prec = fd->result_datafmt.precision;
    fd->scale = fd->result_datafmt.scale;
#if 0
    if (fd->result_datafmt.status & CS_CANBENULL)
       fd->nullok = 1;
    else
       fd->nullok = 0;
#endif
    (void)make_upper(fd->colname);
    if (RxGetRunFlags() == 99) 
      fprintf(stderr,"Name: %s Type: %d Length: %d Scale: %d Prec: %d Null:%d\n",
            fd->colname,fd->coltype,fd->collen,fd->scale,fd->prec,fd->nullok);
    /*
     * These values set up as such to bind all fetched values to
     * NUL terminated strings. They don't represent the actual
     * described statement.
     */
    fd->result_datafmt.maxlength = CalculateDisplayLength(&fd->result_datafmt) + 1;
    fd->result_datafmt.datatype = CS_CHAR_TYPE;
    fd->result_datafmt.format   = CS_FMT_NULLTERM;
    /*
     * To save malloc() and free() calls, we keep the old buffer
     * providing it isn't too big or too small.
     */
    if (fd->rbufl < fd->result_datafmt.maxlength
    ||  fd->rbufl > fd->result_datafmt.maxlength)
      {
       if (fd->rbufl)
         {
          free(fd->rbuf);
          fd->rbufl = 0;
         }
      }
    if ((fd->rbuf = (char *)malloc(fd->result_datafmt.maxlength)) == (char*)NULL)
       return(SetIntError(__FILE__,__LINE__,10, "out of memory"));
    /*
     * Now bind the columns in the statement to the allocated
     * field descriptors...
     */
    if ((ct_bind(swa->cmd,i + 1, &fd->result_datafmt,fd->rbuf, &fd->rbufl,&fd->nullok)) != CS_SUCCEED)
       return(DB_ERROR);
   }
 return (swa->expr_cnt);
}



/*-----------------------------------------------------------------------------
 * Fetches the next row from the nominated cursor and returns the values
 * of the expressions for the fetched row into the compound variable with
 * name constructed as follows:
 *
 * For single fetches. eg. SQLFETCH('s1')
 *                     or  SQLFETCH('s1','') :
 *  <statement-name>.<column-name>
 *
 * For bulk fetches. eg. SQLCOMMAND(stmt1)
 *                   or  SQLFETCH('s1',0)
 *                   or  SQLFETCH('s1',1)
 *                   or  SQLFETCH('s1',20) :
 *  <statement-name>.<column-name>.<row-number>
 *
 * Note that the row-number always starts at 1!
 *
 * Returns:
 *	success:  0
 *	failure:  1
 *
 * This function assumes that all columns to be returned have already been bound
 * to variables.
 *----------------------------------------------------------------------------*/
static int FetchRow

#ifdef HAVE_PROTO
    (STMT *stmt,char *stem,ULONG rowcount)
#else
    (stmt, stem, rowcount)
    STMT    *stmt;
    char    *stem;
    ULONG   rowcount;
#endif
{
 SQLWA   *swa=NULL;
 FLDDSCR  *fd=NULL;
 int	    rc=0, i=0;
 size_t  varlen=0;
 char    varname[MAX_IDENTIFIER+1+10];
 char    tmp[128];
 char    *buffer=NULL;
 int     buflen=0;
 int     coltype=0;
 int     numcols=0;
 int     computeid=0;
 int     colid=0;
 int     use_buffer=0;
 CS_INT  retcode=0;
 CS_INT  rows_read=0;

 swa = SWA(stmt);
 if (swa->state != REXXSQL_STATE_EXECUTED)
   {
    (void)sprintf(tmp,"statement \"%s\" has not been OPENed or EXECUTEd", stmt->name);
    return(SetIntError(__FILE__,__LINE__,26, tmp));
   }

 retcode = ct_fetch(swa->cmd, CS_UNUSED, CS_UNUSED, CS_UNUSED,&rows_read);
 if (retcode != CS_SUCCEED
 &&  retcode != CS_ROW_FAIL)
    return(1); /** ??? */
 /*
  * Check if we hit a recoverable error.
  */
 if (retcode == CS_ROW_FAIL)
   {
    if (RxGetRunFlags() == 99) 
       fprintf(stderr, "Error on row %d.\n", rowcount);
    return(1); /* ?? */
   }
 /*
  * We have a valid row.  
  * Loop through the columns to get the column data
  */
 for (i = 1; rc == 0 && i <= swa->expr_cnt; i++)
   {  
    fd = swa->fa[i-1];
    if (RxGetRunFlags() == 99) 
      fprintf(stderr, "Value of column: <%s>\n", fd->rbuf);
    (void)sprintf(varname, rowcount ? "%s.%s.%lu" : "%s.%s",
                   stem, fd->colname, rowcount);
    varlen = strlen(varname);
    if (RxGetRunFlags() == 99) 
      fprintf(stderr,"FetchRow(): Length of %s: %d NULL:%d<%s>\n",fd->colname,fd->rbufl,fd->nullok,RXSNullStringOut.strptr);
    if (fd->nullok == (-1))
       rc = SetRexxVariable(varname, varlen, RXSNullStringOut.strptr, RXSNullStringOut.strlength);
    else
       rc = SetRexxVariable(varname, varlen, fd->rbuf, fd->rbufl);
   }
 if (rc)
    return(SetIntError(__FILE__,__LINE__,16, "unable to set REXX variable"));
 return rc;
}

/*-----------------------------------------------------------------------------
 *
 *----------------------------------------------------------------------------*/
static int SetRowCountVar

#ifdef HAVE_PROTO
    (SQLWA *swa,char *stem_name,long rowcount)
#else
    (swa, stem_name, rowcount)
    SQLWA *swa;
    char *stem_name;
    long rowcount;
#endif
{
 int     i=0,rc=0;
 char    varname[MAX_IDENTIFIER*2+4], buf[11];

 for (i = 0; i < swa->expr_cnt; i++) 
   {
    sprintf(varname, "%s.%s.0", stem_name,swa->fa[i]->colname);
    sprintf(buf, "%lu", rowcount);
    if (SetRexxVariable(varname,strlen(varname),buf,strlen(buf)))
       return(-16);
   }
 return 0;
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCOMMAND(stem-name, sql-statement-text)
 *
 * RETURNS :  0-success < 0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLCOMMAND

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int         rc = 0, i=0;
 ULONG       rowcount=0L;
 ULONG       computecount=0L;
 DBCON       *db=NULL;
 STMT        *stmt=NULL;
 SQLWA       *swa=NULL;
 char        stem_name[MAX_IDENTIFIER+1];
 CS_INT       result_type=0;
 CS_INT       num_rows=0;
 CS_INT       num_cols=0;
 int          expr_cnt=0;
 CS_RETCODE   retcode=0;

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc == 0) return 1;

 /* 
  * Get pointer to current connection 
  */
 if (DbEnv && DbEnv->current_connection)
     db = DbEnv->current_connection;
 else
     return ReturnError(retstr, 25, "no connection is current");

 if (argc == 1 || RXSTRLEN(argv[0]) == 0) /* No stem name specified! */
     (void)strcpy(stem_name, DEFAULT_STEM);
 else 
   {
    if ((rc = MkIdentifier(argv[0], stem_name, sizeof(stem_name))))
       return RxReturnNumber(retstr, rc);
   }

 /* 
  * If no default statement then create it! 
  */
 if ((stmt = (STMT*)(db->dflt_stmt)) == (STMT*)NULL) 
   {
    /* 
     * Open a statement for the default statement. 
     */
    if ((rc = OpenStatement(DEFAULT_STATEMENT, db, &stmt)))
       return RxReturnNumber(retstr, (long)rc);
    db->dflt_stmt = (void*)stmt;
   }

 swa = SWA(stmt);

 swa->state = REXXSQL_STATE_IDLE;

 /*
  * If only 1 arg then it is the SQL-statement-text. If more than 1 args
  * then arg#1 is stem-name, arg#2 is text.
  * 'i' is index (base zero) to sql-statement-text arg.
  */
 i = (argc == 1) ? 0 : 1;

 /* 
  * set flag indicating if SELECT statement supplied 
  */
 swa->select = SelectStatement(RXSTRPTR(argv[i]),RXSTRLEN(argv[i]));

 /* 
  * Save the SQL statement if required 
  * This MUST always be done for Sybase
  */
 if (SaveSqlStatement(&(swa->sql_stmt), &(swa->sql_stmt_sz), RXSTRPTR(argv[i]),(int)RXSTRLEN(argv[i])))
     return ReturnError(retstr, 10, "out of memory");

 /* 
  * Prepare the SQL statement
  */
 if (RxGetRunFlags() == 99) 
    fprintf(stderr, "ct_dynamic(PREPARE) <%s>\n",SQL(swa));
 if (ct_dynamic(swa->cmd, CS_PREPARE, stem_name, CS_NULLTERM, SQL(swa), CS_NULLTERM) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 if (ct_send(swa->cmd) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"Line: %d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 while ((retcode = ct_results(swa->cmd, &result_type)) == CS_SUCCEED)
   {
    if (DBErrorPending)
      {
       SetDBError(SWA(stmt));
       return RxReturnNumber(retstr, DB_ERROR);
      }
    switch(result_type)
      {
       case CS_ROW_RESULT:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) row results\n");
/*            	retcode = prcs_result_data(CMD_ptr);*/
            break;
       case CS_DESCRIBE_RESULT:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) describe results\n");
/*
  This might examine descriptors' name, datatype, etc and prompt for values
    get_input_paramaters (cmd,parms);
*/
            break;
       case CS_CURSOR_RESULT:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) cursor results\n");
/*            retcode = prcs_result_data(CMD_ptr);*/
            break;
       case CS_CMD_SUCCEED:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) no addition results\n");
            break;
       case CS_CMD_DONE:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) done with 1 result set\n");
            break;
       case CS_CMD_FAIL:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) result set failure\n");
            break;
       default:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(PREPARE) unexpected result type (%d)\n",result_type);
            break;
      }
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 switch (retcode)
   {
    case CS_END_RESULTS:
         break;
    case CS_FAIL:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "ct_results for (PREPARE) failed\n");
         break;
    default:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "ct_results for (PREPARE) unexpected return code (%d)\n",retcode);
         return (retcode);
         break;
   }
fprintf(stderr,"Line: %d\n",__LINE__);

 swa->state = REXXSQL_STATE_PREPARED;

fprintf(stderr,"Line: %d\n",__LINE__);
 /* 
  * Bind variables in WHERE/INSERT/UPDATE clause (if any). 
  * This first step determines the number of bind values only.
  */
 if (argc > 2) 
   {
    if ((rc = BindValues(stmt, stem_name, 1, argc-2, &argv[2])))
      {
       return RxReturnNumber(retstr, (long)rc);
      }
   }

 /* 
  * Execute the SQL statement
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 if (ct_dynamic(swa->cmd, CS_EXECUTE, stem_name, CS_NULLTERM, NULL, CS_UNUSED) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"Line: %d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
 /* 
  * Bind variables in WHERE/INSERT/UPDATE clause (if any). 
  * This second step associates bind values via ct_param().
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 if (argc > 2) 
   {
    if ((rc = BindValues(stmt, stem_name, 0, argc-2, &argv[2])))
      {
       return RxReturnNumber(retstr, (long)rc);
      }
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 if (ct_send(swa->cmd) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"Line: %d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 while ((retcode = ct_results(swa->cmd, &result_type)) == CS_SUCCEED)
 {
fprintf(stderr,"Line: %d\n",__LINE__);
    swa->state = REXXSQL_STATE_EXECUTED;
    switch(result_type)
    {
       case CS_ROW_RESULT:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) row results\n");
          /* 
           * Get field definitions 
           */
          rc = DefineExpressions(stmt,stem_name);
          if (rc < 0)
             return RxReturnNumber(retstr, rc);
          /*
           * Fetch the rows now - if there are any
           */
          for (rowcount = 1; RowLimit == 0 || rowcount <= RowLimit; rowcount++)
          {
             if (RxGetRunFlags() == 99) 
                fprintf(stderr, "ct_dynamic(EXECUTE) row num: %d\n",rowcount);
             if ((rc = FetchRow(stmt, stem_name, rowcount)))
                break;
          }
          rowcount--;

          if (rc && rc != NO_DATA_FOUND) 
          {
             return RxReturnNumber(retstr, (long)rc);
          }

          if ((rc = SetRowCountVar(swa, stem_name, rowcount)))
             return RxReturnNumber(retstr, (long)rc);
          break;
       case CS_DESCRIBE_RESULT:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) describe results\n");
/*
            if (ct_res_info(swa->cmd,CS_NUMDATA,&num_expr_vars,CS_UNUSED,NULL) != CS_SUCCEED
            ||  DBErrorPending)
              {
               SetDBError(swa);
               return(DB_ERROR);
              }
*/
/*
  This might examine descriptors' name, datatype, etc and prompt for values
    get_input_paramaters (cmd,parms);
*/
          break;
       case CS_CURSOR_RESULT:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) cursor results\n");
          break;
       case CS_CMD_SUCCEED:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) no additional results\n");
#if 0
            if (!swa->select)
              {
               if (ct_res_info(swa->cmd,CS_ROW_COUNT,&num_rows,CS_UNUSED,NULL) != CS_SUCCEED
               ||  DBErrorPending)
                 {
                  SetDBError(swa);
                  return RxReturnNumber(retstr, DB_ERROR);
                 }
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) CS_CMD_SUCCEED num_rows: %d\n",num_rows);
               rowcount = (num_rows==(-1)?0:num_rows);
              }
#endif
          break;
       case CS_CMD_DONE:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) done with 1 result set\n");
          if (!swa->select)
          {
fprintf(stderr,"Line: %d\n",__LINE__);
             if (ct_res_info(swa->cmd,CS_ROW_COUNT,&num_rows,CS_UNUSED,NULL) != CS_SUCCEED
             ||  DBErrorPending)
             {
fprintf(stderr,"Line: %d\n",__LINE__);
                SetDBError(swa);
                return RxReturnNumber(retstr, DB_ERROR);
             }
             if (RxGetRunFlags() == 99) 
                fprintf(stderr, "ct_dynamic(EXECUTE) CS_CMD_DONE num_rows: %d\n",num_rows);
             rowcount = (num_rows==(-1)?0:num_rows);
fprintf(stderr,"Line: %d\n",__LINE__);
          }
fprintf(stderr,"Line: %d\n",__LINE__);
          break;
       case CS_CMD_FAIL:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) result set failure: %d <%s>\n",DBErrorPending,LastDBError);
          SetDBError(swa);
          return RxReturnNumber(retstr, DB_ERROR);
          break;
       case CS_ROWFMT_RESULT:
fprintf(stderr,"Line: %d\n",__LINE__);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "ct_dynamic(EXECUTE) rowfmt results\n");
#if 0
            if (ct_res_info(swa->cmd,CS_NUMDATA,&num_rows,CS_UNUSED,NULL) != CS_SUCCEED
            ||  DBErrorPending)
              {
               SetDBError(swa);
               return RxReturnNumber(retstr, DB_ERROR);
              }
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(EXECUTE) rowfmt results: %d\n",num_rows);
#endif
          break;
       default:
fprintf(stderr,"Line: %d (%d)\n",__LINE__,result_type);
          if (RxGetRunFlags() == 99) 
             fprintf(stderr, "\nl4_exec_dyn: unexpected result type (%d)",result_type);
          break;
    }
 }
fprintf(stderr,"Line: %d\n",__LINE__);

 if (DBErrorPending)
 {
fprintf(stderr,"Line: %d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
 }
fprintf(stderr,"Line: %d\n",__LINE__);
 switch (retcode)
   {
    case CS_END_RESULTS:
         break;
    case CS_FAIL:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "\nl4_exec_dyn: ct_results() failed");
         break;
    default:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "\nl4_exec_dyn: ct_results() unexpected return code");
         return (retcode);
         break;
   }

fprintf(stderr,"Line: %d\n",__LINE__);
 /* 
  * Deallocate the SQL statement
  */
 if (ct_dynamic(swa->cmd, CS_DEALLOC, stem_name, CS_NULLTERM, NULL, CS_UNUSED) != CS_SUCCEED
 ||  DBErrorPending)
   {
fprintf(stderr,"Line: %d\n",__LINE__);
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 if (ct_send(swa->cmd) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 while ((retcode = ct_results(swa->cmd, &result_type)) == CS_SUCCEED)
   {
fprintf(stderr,"Line: %d\n",__LINE__);
    if (DBErrorPending)
      {
       SetDBError(SWA(stmt));
       return RxReturnNumber(retstr, DB_ERROR);
      }
    switch(result_type)
      {
       case CS_CMD_SUCCEED:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(DEALLOC) no additional results\n");
            break;
       case CS_CMD_DONE:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "ct_dynamic(DEALLOC) done with 1 result set\n");
            break;
       default:
       if (RxGetRunFlags() == 99) 
            fprintf(stderr, "\nl4_exec_dyn: unexpected result type (%d)",result_type);
            break;
      }
   }
fprintf(stderr,"Line: %d\n",__LINE__);
 switch (retcode)
   {
    case CS_END_RESULTS:
         break;
    case CS_FAIL:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "\nl4_exec_dyn: ct_results() failed");
         break;
    default:
    if (RxGetRunFlags() == 99) 
         fprintf(stderr, "\nl4_exec_dyn: ct_results() unexpected return code");
         return (retcode);
         break;
   }
 /*
  * If the statement is NOT a SELECT, and we have AUTOCOMMIT
  * ON, then commit the statement.
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 if (!swa->select
 &&  AutoCommit)
   {
    if ((rc = SQLTRANSACT(name, argc, argv, stck, retstr,SQL_COMMIT)))
       return RxReturnNumber(retstr, rc);
   }

fprintf(stderr,"Line: %d\n",__LINE__);
 /*
  * Inform database that operation is complete
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 if (CTX(swa))
   {
    ct_cancel(NULL,swa->cmd,CS_CANCEL_ALL);
    CTX(swa) = NULL;
   }
 /* 
  * Set the SQLCA.ROWCOUNT variable
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 SetRowCount(rowcount);
 SetComputeCount(computecount);

 /* 
  * Release the statement and associated storage. 
  */
fprintf(stderr,"Line: %d\n",__LINE__);
 if ((rc = ReleaseStatement(stmt)))
    return RxReturnNumber(retstr, (long)rc);
 db->dflt_stmt = (STMT*)NULL;

 return RxReturnNumber(retstr, 0L);
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLPREPARE(statement-name, sql-statement-text)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLPREPARE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int         rc=0;
 DBCON       *db=NULL;
 STMT        *stmt=NULL;
 SQLWA	*swa=NULL;
 char        stmt_name[MAX_IDENTIFIER+1];
 CS_INT      result_type=0;
 CS_RETCODE  retcode=0;

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc != 2) return 1;

 /* 
  * Get pointer to current connection 
  */
 if (DbEnv && DbEnv->current_connection)
     db = DbEnv->current_connection;
 else
     return ReturnError(retstr, 25, "no connection is current");

 if (RXSTRLEN(argv[0]) == 0)		/* No statement name specified! */
     return ReturnError(retstr, 18, "statement name omitted or null");
 else if ((rc = MkIdentifier(argv[0], stmt_name, sizeof(stmt_name))))
     return RxReturnNumber(retstr, rc);

 /*
  * Find the named statement or create if necessary. We have to be a
  * bit careful here because the statement may exist but point to a
  * different database connection!
  */
 stmt = FindObject(stmt_name, DbEnv->stmt_tbl, TBL_STATEMENTS);

 if (stmt == (STMT*)NULL || stmt->db != db) 
   {
    if (stmt) 
      {
       /*
        * Statement is not for the same db, therefore we must dispose
        * & re-alloc it!
        */
       RemoveObject(stmt);
       ((DBCON*)stmt->db)->num_statements--;
       if ((rc = ReleaseStatement(stmt)))
          return RxReturnNumber(retstr, (long)rc);
      }

    /* 
     * Open a statement for this statement. 
     */
    if ((rc = OpenStatement(stmt_name, db, &stmt)))
       return RxReturnNumber(retstr, (long)rc);

    /* 
     * Insert this statement into the connection hash table. 
     */
    (void)InsertObject(stmt, DbEnv->stmt_tbl, TBL_STATEMENTS);

    db->num_statements++;
   }

 swa = SWA(stmt);

 /* 
  * Save the SQL statement if required
  * This MUST always be done for Sybase 
  */

 if (SaveSqlStatement(&(swa->sql_stmt), &(swa->sql_stmt_sz), RXSTRPTR(argv[1]),(int)RXSTRLEN(argv[1])))
     return ReturnError(retstr, 10, "out of memory");

 swa->expr_cnt = 0;

 /* 
  * Prepare the SQL statement
  */
 if (ct_dynamic(swa->cmd, CS_PREPARE, stmt_name, CS_NULLTERM, SQL(swa), CS_NULLTERM) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
 if (ct_send(swa->cmd) != CS_SUCCEED
 ||  DBErrorPending)
   {
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }
 while(1)
   {
    retcode = ct_results(swa->cmd,&result_type);
    if (retcode != CS_SUCCEED
    ||  DBErrorPending)
       break;
   }
 if (retcode != CS_END_RESULTS
 ||  DBErrorPending)
   {
    SetDBError(SWA(stmt));
    return RxReturnNumber(retstr, DB_ERROR);
   }

 return RxReturnNumber(retstr, rc ? DB_ERROR : 0);
}



/*-----------------------------------------------------------------------------
 * Get a pointer to the nominated statement. Returns NULL on error.
 *----------------------------------------------------------------------------*/
static STMT *GetStatement

#ifdef HAVE_PROTO
    (RXSTRING	var,PSZ		buf)
#else
    (var, buf)
    RXSTRING	var; 
    PSZ		buf;
#endif
{
 STMT        *stmt=NULL;
 char        tmp[128];

 if (DbEnv == (DBENV*)NULL) 
   {
    SetIntError(__FILE__,__LINE__,22, "no connections open.");
    return (STMT*)NULL;
   }

 if (RXSTRLEN(var) == 0)   /* No statement name specified! */
   {
    SetIntError(__FILE__,__LINE__,23, "statement name omitted or null");
    return (STMT*)NULL;
   }

 /* Get the normalised form of the name */
 if (MkIdentifier(var, buf, MAX_IDENTIFIER+1))
    return (STMT*)NULL;

 /* Find the named statement or create if necessary */
 if ((stmt = FindObject(buf, DbEnv->stmt_tbl, TBL_STATEMENTS))
                                       == (STMT*)NULL) 
   {
    /* Statement not an existing one! */
    (void)sprintf(tmp,"statement \"%s\" does not exist", buf);
    SetIntError(__FILE__,__LINE__,24, tmp);
    return (STMT*)NULL;
   }
 return stmt;
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDISPOSE(statement-name)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLDISPOSE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int         rc=0;
 STMT        *stmt=NULL;
 DBCON       *db=NULL;
 char        stmt_name[MAX_IDENTIFIER+1];

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc != 1) return 1;

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 /* Get pointer to statement's connection structure */
 db = stmt->db;

 /* Dispose the statement */
 RemoveObject(stmt);
 rc = ReleaseStatement(stmt);

 db->num_statements--;

 return RxReturnNumber(retstr, (long)rc);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLEXEC (called by SQLEXECUTE() and SQLOPEN()
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLEXEC

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr,int open)
#else
    (name, argc, argv, stck, retstr, open)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
    int open;
#endif
{
 ULONG	rowcount=0L;
 STMT        *stmt=NULL;
 SQLWA	*swa=NULL;
 DBCON       *db=NULL;
 char        stmt_name[MAX_IDENTIFIER+1];
 char        tmp[128];
 CS_INT      num_rows=0;

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc == 0) return 1;

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 swa = SWA(stmt);

 /*
  * Make sure we have a current connection
  */
 if (DbEnv == (DBENV*)NULL)
    return ReturnError(retstr, 22, "no connections open.");

 /* 
  * Get pointer to current connection 
  */
 if (DbEnv && DbEnv->current_connection)
    db = DbEnv->current_connection;
 else
    return ReturnError(retstr, 25, "no connection is current");

 /*
  * This function can be called as SQLOPEN() or SQLEXECUTE(). These
  * operations are similar except for the describe. Use the function
  * name to determine what operation we are performing.
  */

#if 0
 /* 
  * Save results if we haven't already done it for this statement 
  */
 if (!CTX(swa))
   {
    CTX(swa) = db->conn_handle;
    dbresults(db->conn_handle);
   }
 /* 
  * If called from SQLOPEN() the statement must be a query! 
  */
 if (open
 &&  CTX(swa) == NULL)
   {
    (void)sprintf(tmp,"statement \"%s\" is not a query.", stmt_name);
    return ReturnError(retstr, 13, tmp);
   }

 /*
  * Return the ROWCOUNT. 
  */
 if (CTX(swa))
   {
    if (ct_res_info(swa->cmd,CS_ROW_COUNT,&num_rows,CS_UNUSED,NULL) != CS_SUCCEED
    ||  DBErrorPending)
      {
       SetDBError(SWA(stmt));
       return RxReturnNumber(retstr, DB_ERROR);
      }
    rowcount = num_rows;
   }
#endif
 SetRowCount(rowcount);
 return RxReturnNumber(retstr, (long)0L);
}


/*-----------------------------------------------------------------------------
 * SYNOPSIS: SQLCLOSE(statement-name)
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLCLOSE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int         rc=0;
 STMT        *stmt=NULL;
 SQLWA	*swa=NULL;
 char        stmt_name[MAX_IDENTIFIER+1];

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc != 1) return 1;

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 swa = SWA(stmt);

#if 0
 /* Inform database that operation is complete. This should never fail! */
 if (CTX(swa))
   {
    dbcancel(CTX(swa));
    CTX(swa) = NULL;
   }
#endif

 return RxReturnNumber(retstr, rc ? DB_ERROR : 0);
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLFETCH(statement-name [, number-of-rows])
 *
 * RETURNS :  0-end-of-data,
 *           >0- single fetch: row number of last row fetched
 *           >0- group fetch : number of rows fetched if < number-of-rows then
 *                             end--of-data is indicated.
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLFETCH

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 long        rc=0;
 int         single_fetch=0;
 ULONG       num_rows=0L;
 ULONG       rowcount=0L;
 STMT        *stmt=NULL;
 SQLWA	*swa=NULL;
 char        stmt_name[MAX_IDENTIFIER+1];
 char        tmp[128];

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc == 0 || argc > 2) return 1;

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 swa = SWA(stmt);

 if (!CTX(swa))
   {
    (void)sprintf(tmp,"statement \"%s\" has not been OPENed or EXECUTEd", stmt->name);
    return ReturnError(retstr, 26, tmp);
   }

 /* 
  * Determine # of rows to fetch 
  */
 if (argc > 1 && RXSTRLEN(argv[1])) 
   {
    if (StrToInt(&argv[1], &num_rows)) 
      {
       return ReturnError(retstr, 14,"<num-rows> is not a valid integer.");
      }
    single_fetch = FALSE;
   }
 else
    single_fetch = TRUE;

 /* 
  * Get field definitions 
  */
 rc = DefineExpressions(stmt,stmt_name);
 if (rc < 0)
   {
    (void)sprintf(tmp,"statement \"%s\" has not been OPENed or EXECUTEd", stmt->name);
    return ReturnError(retstr, 26, tmp);
   }

 if (single_fetch) 
   {
    /* 
     * Fetch a single row 
     */
    if ((rc = FetchRow(stmt, stmt_name, 0L)))
       rc = (rc == NO_DATA_FOUND) ? 0 : rc;
    else
      {
#if defined(DB_LIBRARY)
       rc = DBCOUNT(CTX(swa));
#else
#endif
      }
   }
 else 
   {
    /* 
     * Fetch each row in turn 
     */
    for (rowcount = 1; num_rows == 0 || rowcount <= num_rows; rowcount++)
      {
       if ((rc = FetchRow(stmt, stmt_name, rowcount)))
          break;
      }

    rowcount--;

    if (rc && rc != NO_DATA_FOUND) 
      {
       return RxReturnNumber(retstr, (long)rc);
      }

    if ((rc = SetRowCountVar(swa, stmt_name, rowcount)))
       return RxReturnNumber(retstr, (long)rc);

    rc = rowcount;
   }

#if defined(DB_LIBRARY)
 SetRowCount(DBCOUNT(CTX(swa)));
#else
#endif
 return RxReturnNumber(retstr, rc);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLGETDATA(statement-name, column-name, start-byte, length [, file-name])
 *
 * RETURNS :  0-end-of-data,
 *           >0- bytes obtained - <= length
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLGETDATA

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
#define LONG_BLOCK_SIZE 0x10000

 long    rc=0,ret_len=0;
#if 0
 FLDDSCR *fd=NULL;
 ULONG   num_bytes=0L;
 ULONG   start_byte=0L;
 STMT    *stmt=NULL;
 SQLWA   *swa=NULL;
 char    stmt_name[MAX_IDENTIFIER+1];
 int     long_col = 0,ext_type = 0,i = 0;
 size_t  varlen=0;
 char    varname[MAX_IDENTIFIER+1+10];
 FILE    *fp=NULL;
 char    tmp[128];                      

 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc < 4 || argc > 5) return 1;

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 swa = SWA(stmt);

 /* 
  * Check that the column name specified is really a "LONG" and
  * get column number.
  */
 if (RXSTRLEN(argv[1]))
   {
    for (i=0;i<swa->expr_cnt;i++)
      {
       fd = swa->fa[i];
       if (memcmp(RXSTRPTR(argv[1]),fd->cbuf,RXSTRLEN(argv[1])) == 0)
         {
          /*
           * Found column name, is it a "LONG" ?
           */
          if (!DBLONGCOLUMN(fd->dbtype))
            {
             sprintf(tmp,"Column <%s> does not have a 'LONG' datatype.",fd->cbuf);
             return ReturnError(retstr, 85,tmp);
            }
          long_col = i+1;
          break;
         }
      }
    if (long_col == 0)
      {
       sprintf(tmp,"Column <%s> not present in statement.",fd->cbuf);
       return ReturnError(retstr, 85,tmp);
      }
   }
 else
   {
    return ReturnError(retstr, 84,"<column-name> parameter MUST be supplied.");
   }

 /* 
  * Determine starting byte
  */
 if (RXSTRLEN(argv[2]))
   {
    if (StrToInt(&argv[2], &start_byte))
      {
       return ReturnError(retstr, 14,"<start-byte> is not a valid integer.");
      }
   }
 else
     start_byte = 0L;

 /* 
  * Determine length
  */
 if (RXSTRLEN(argv[3]))
   {
    if (StrToInt(&argv[3], &num_bytes))
      {
       return ReturnError(retstr, 14,"<number-bytes> is not a valid integer.");
      }
   }
 else
     num_bytes = 0L;

 /* 
  * Check for filename if start and length = 0
  */
 if (start_byte == 0L
 &&  num_bytes == 0L
 &&  RXSTRLEN(argv[4])==0)
   {
    return ReturnError(retstr, 84,"<file-name> parameter MUST be supplied.");
   }

 if (start_byte == 0L
 &&  num_bytes == 0L)
   {
    /*
     * Process a file
     */
    ub1 *buf=NULL;

    ext_type = (fd->dbtype==ORA_LONG)?EXT_CHAR:EXT_LONG_RAW;
    if ((fp = fopen(RXSTRPTR(argv[4]),"wb")) == NULL)
      {
       sprintf(tmp,"<open> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
       return ReturnError(retstr, 86,tmp);
      }
    if ((buf = (ub1*)malloc(LONG_BLOCK_SIZE+1)) == (ub1*)NULL)
       return ReturnError(retstr, 10, "out of memory");
    ret_len = 0;
    for (i=0;;i++)
      {
       if (oflng(CTX(swa),long_col,buf,LONG_BLOCK_SIZE,ext_type,&ret_len,i*LONG_BLOCK_SIZE))
         {
          if (buf) free(buf);
          SetDBError(LDA(stmt), swa);
          return RxReturnNumber(retstr, DB_ERROR);
         }
       if (ret_len == 0)
          break;
       if (fwrite((void*)buf,sizeof(ub1),ret_len,fp) != ret_len)
         {
          if (buf) free(buf);
          sprintf(tmp,"<write> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
          return ReturnError(retstr, 86, tmp);
         }
      }
    if (buf) free(buf);
    if (fclose(fp))
      {
       sprintf(tmp,"<close> on file <%s> failed: %s.",RXSTRPTR(argv[4]),strerror(errno));
       return ReturnError(retstr, 86, tmp);
      }
   }
 else 
   {
    /* 
     * Get the chunk of data specified
     * Size of the chunk MUST be < 64K
     */
    if (num_bytes > 0x10000)
       return ReturnError(retstr, 87,"<number-bytes> parameter must be <= <64K>.");
    ext_type = (fd->dbtype==ORA_LONG)?EXT_CHAR:EXT_LONG_RAW;
    /*
     * In an attempt to save malloc() & free() calls we keep the old
     * buffer providing it is not grossly oversized. 
     */
    if ((size_t)fd->rbufl < num_bytes 
    || (size_t)fd->rbufl > num_bytes + 256)
      {
       /* Free the old buffer (if any) */
       if (fd->rbufl) 
         {
          free(fd->rbuf);
          fd->rbufl = 0;
         }
       /* Allocate a new buffer */
       if ((fd->rbuf = (ub1*)malloc(num_bytes)) == (ub1*)NULL)
          return ReturnError(retstr, 10, "out of memory");
      }
    fd->rbufl = num_bytes;
    if (oflng(CTX(swa),long_col,fd->rbuf,fd->rbufl,ext_type,&ret_len,start_byte-1))
      {
       SetDBError(LDA(stmt), swa);
       return RxReturnNumber(retstr, DB_ERROR);
      }
    (void)sprintf(varname, "%s.%s", stmt_name, fd->cbuf);
    varlen = strlen(varname);
    rc = SetRexxVariable(varname, varlen, fd->rbuf, ret_len);
   }
#endif

 return RxReturnNumber(retstr, ret_len);
}


/*-----------------------------------------------------------------------------
 * Fetch the description for the column expression. Used by SQLDESCRIBE().
 *----------------------------------------------------------------------------*/
static int GetColumn

#ifdef HAVE_PROTO
    (SQLWA *swa,int i,char *stem_name)
#else
    (swa, i, stem_name)
    SQLWA   *swa;
    int	    i;
    char    *stem_name;
#endif
{
 FLDDSCR *fd=NULL;
 int     idx=0, rc=0;
 char    column_size[15], column_scale[15], column_precision[15], column_primarykey[15], column_nullok[15];
 char    *column_type=NULL;
 char    name[MAX_IDENTIFIER+32];
 char    *value[NUM_DESCRIBE_COLUMNS];
 int     value_len[NUM_DESCRIBE_COLUMNS];

 if (i >= swa->expr_cnt)
    return 1;

 fd = swa->fa[i];

 /* 
  * Set up the array 
  */
 value[0] = fd->colname;
 value_len[0] = strlen(fd->colname);
 value[1] = column_type;
 value_len[1] = strlen(column_type);
 value[2] = column_size;
 value_len[2] = (int)sprintf(column_size, "%d", fd->collen);
 value[3] = column_precision;
 value_len[3] = (int)sprintf(column_precision, "%d", fd->prec);
 value[4] = column_scale;
 value_len[4] = (int)sprintf(column_scale, "%ld",fd->scale);
 value[5] = column_nullok;
 value_len[5] = (int)sprintf(column_nullok, "%d",fd->nullok);

 /* 
  * Output into Rexx variable 
  */
 i++;
 for (idx = 0; idx < NUM_DESCRIBE_COLUMNS; idx++) 
   {
    sprintf(name, "%s.COLUMN.%s.%d", stem_name,column_attribute[idx], i);
    if (SetRexxVariable(name,strlen(name),value[idx],value_len[idx]))
      {
       rc = -16;
       break;
      }
   }

 return rc;
}



/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLDESCRIBE(statement-name [, stem-name])
 *
 * RETURNS : >0-number of columns in the prepared SELECT statement.
 *            0-prepared statement is not a SELECT statement.
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLDESCRIBE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE	name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE	stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 int         i=0, len1=0, len2=0, rc=0;
 STMT        *stmt=NULL;
 SQLWA	*swa=NULL;
 DBCON       *db=NULL;
 char        **p=NULL, buf1[MAX_IDENTIFIER+32], buf2[16];
 char        stmt_name[MAX_IDENTIFIER+1];
 char        tmp[128];
 char        stem_name[MAX_IDENTIFIER+1];


 FunctionPrologue(name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc < 1 || argc > 2) return 1;

 /* Get pointer to current connection */
 if (DbEnv && DbEnv->current_connection)
     db = DbEnv->current_connection;
 else
     return ReturnError(retstr, 25, "no connection is current");

 if ((stmt = GetStatement(argv[0], stmt_name)) == (STMT*)NULL)
     return RxReturnNumber(retstr, SQLCA_IntCode);
 
 swa = SWA(stmt);

 /* Get the name of the stem into which to put output */
 if (argc < 2 || RXSTRLEN(argv[1]) == 0) /* No stem name specified! */
    (void)strcpy(stem_name, stmt_name);
 else 
    if ((rc = MkIdentifier(argv[1], stem_name, sizeof(stem_name))))
       return RxReturnNumber(retstr, (long)rc);

 /* 
  * Save results if we haven't already done it for this statement 
  */
 if (CTX(swa) == NULL)  /* not SELECT */
   {
    (void)sprintf(tmp,"statement \"%s\" is not a query.", stmt_name);
    return ReturnError(retstr, 13, tmp);
   }

 /* Describe the expression list & define output buffers (if any). */
 if ((rc = DefineExpressions(stmt,stmt_name)) < 0)
     return RxReturnNumber(retstr, (long)rc);

 /* Describe the parsed statement into REXX variables */
 for (rc = 0, i = 0; rc == 0; i++) 
   {
    rc = GetColumn(swa, i, stem_name);
   }

 if (rc >= 0) 
   {
    len2 = (int)sprintf(buf2,"%d", --i);
    for (p = column_attribute; *p && rc >= 0; p++) 
      {
       len1 = (int)sprintf(buf1, "%s.COLUMN.%s.0", stem_name, *p);
       if (SetRexxVariable(buf1, len1, buf2, len2))
          rc = -16;
       else
          rc = 0;
      }
    rc = rc < 0 ? rc : i;
   }

 return RxReturnNumber(retstr, (long)rc);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  DBInitialise ( void )
 *----------------------------------------------------------------------------*/
int DBInitialise
#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif
{
 CS_INT propvalue=0;
 strcpy(SQLCA_SqlState,"");

 if (DbEnv == (DBENV*)NULL) 
   {
    if ((DbEnv = AllocDbEnvironment()) == (DBENV*)NULL)
      {
       SetIntError(__FILE__,__LINE__,10, "out of memory.");
       return (DB_ERROR);
      }
   }
 if (cs_ctx_alloc(CS_VERSION_100, &DbEnv->cs_context) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "out of memory.");
    return (DB_ERROR);
   }
 if (ct_init(DbEnv->cs_context, CS_VERSION_100) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }
 if (cs_config(DbEnv->cs_context, CS_SET, CS_MESSAGE_CB,
               (CS_VOID *)sybcsmsg_handler, CS_UNUSED, NULL) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }
 propvalue = CS_TRUE;
 if (ct_config(DbEnv->cs_context, CS_SET, CS_EXTRA_INF,
               (CS_VOID *)&propvalue, CS_UNUSED, NULL) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }
 propvalue = CS_TRUE;
 if (ct_config(DbEnv->cs_context, CS_SET, CS_EXPOSE_FMTS,
               (CS_VOID *)&propvalue, CS_UNUSED, NULL) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }
 if (ct_callback(DbEnv->cs_context, NULL, CS_SET, CS_CLIENTMSG_CB,
               (CS_VOID *)sybclimsg_handler) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }
 if (ct_callback(DbEnv->cs_context, NULL, CS_SET, CS_SERVERMSG_CB,
               (CS_VOID *)sybsrvmsg_handler) != CS_SUCCEED)
   {
    SetIntError(__FILE__,__LINE__,10, "??????");
    return (DB_ERROR);
   }

 return(0);
}

/*-----------------------------------------------------------------------------
 * Set up the string containing database name
 *----------------------------------------------------------------------------*/
static void *SetDBMSName

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif

{
 strcpy(DBMSName,"SYBASE");
 MAKERXSTRING(RXSDBMSName,DBMSName,(ULONG)strlen(DBMSName));
 return((void*)&RXSDBMSName);
}

/*-----------------------------------------------------------------------------
 * Set up the DBMSVer variable
 *----------------------------------------------------------------------------*/
static void *SetDBMSVer

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif

{
 strcpy(DBMSVer,"unknown");
 MAKERXSTRING(RXSDBMSVer,DBMSVer,(ULONG)strlen(DBMSVer));
 return((void*)&RXSDBMSVer);
}

/*-----------------------------------------------------------------------------
 * Set up the Datatypes supported
 *----------------------------------------------------------------------------*/
static void *SetDatatypes

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif

{
 int i=0;
 RXSTRING_DT *dt;

 dt = (RXSTRING_DT *)malloc(sizeof(RXSTRING_DT)*(MAX_DATATYPES+1));
 for (i=0;i<MAX_DATATYPES,(datatype_conversion[i].ext_datatype!=NULL);i++)
   {
    dt[i].strptr = (char*)malloc(strlen(datatype_conversion[i].ext_datatype)+1);
    strcpy(dt[i].strptr, datatype_conversion[i].ext_datatype);
    dt[i].strlength = strlen(datatype_conversion[i].ext_datatype);
    dt[i].internal = datatype_conversion[i].int_datatype;
   }
 dt[i].strptr = NULL;
 dt[i].strlength = 0;
 dt[i].internal = 0;
 return((void*)dt);
}

/*-----------------------------------------------------------------------------
 * Set up the Describe Columns supported
 *----------------------------------------------------------------------------*/
static void *SetDescribeColumns

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif

{
 int i=0;
 RXSTRING *dc=NULL;

 dc = (RXSTRING *)malloc(sizeof(RXSTRING)*(NUM_DESCRIBE_COLUMNS+1));
 for (i=0;i<NUM_DESCRIBE_COLUMNS;i++)
   {
    dc[i].strptr = (char*)malloc(strlen(column_attribute[i])+1);
    strcpy(dc[i].strptr, column_attribute[i]);
    dc[i].strlength = strlen(column_attribute[i]);
   }
 dc[i].strptr = NULL;
 dc[i].strlength = 0;
 return((void*)dc);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsTransactions variable
 *----------------------------------------------------------------------------*/
static void *SetSupportsTransactions

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (idb)
    DBCON *idb;
#endif
{
 InternalTrace("SetSupportsTransactions");
 return((void*)&SupportsTransactions);
}

/*-----------------------------------------------------------------------------
 * Set up the SupportsSqlGetData variable
 *----------------------------------------------------------------------------*/
static void *SetSupportsSqlGetData

#ifdef HAVE_PROTO
    (DBCON *db)
#else
    (db)
    DBCON *db;
#endif
{
 InternalTrace("SetSupportsSqlGetData");
 return((void*)&SupportsSqlGetData);
}


CS_RETCODE CS_PUBLIC sybclimsg_handler

#ifdef HAVE_PROTO
    (CS_CONTEXT *context, SYB_CONN_HANDLE *conn_handle, CS_CLIENTMSG *message)
#else
    (context, conn_handle, message)
    CS_CONTEXT *context;
    SYB_CONN_HANDLE *conn_handle;
    CS_CLIENTMSG *message;
#endif
{
fprintf(stderr,"%d\n",__LINE__);
 if (CS_SEVERITY(message->msgnumber) == CS_SV_INFORM)
    return(CS_SUCCEED);
 DBErrorPending = TRUE;
 SQLCA_SqlCode = message->msgnumber;
 if (message->sqlstatelen > 0)
    strcpy(SQLCA_SqlState,message->sqlstate);
 sprintf (LastDBError, "SYB-Client Message: Layer:%ld, Origin:%ld, Severity:%ld, Number:%ld, %s%s%s",
                       CS_LAYER(message->msgnumber), 
                       CS_ORIGIN(message->msgnumber),
                       CS_SEVERITY(message->msgnumber),
                       CS_NUMBER(message->msgnumber),
                       message->msgstring,
                       (message->osnumber==0)?"":"\n",
                       (message->osnumber==0)?"":message->osstring);
 return(CS_SUCCEED);
}
CS_RETCODE CS_PUBLIC sybsrvmsg_handler

#ifdef HAVE_PROTO
    (CS_CONTEXT *context, SYB_CONN_HANDLE *conn_handle, CS_SERVERMSG *message)
#else
    (context, conn_handle, message)
    CS_CONTEXT *context;
    SYB_CONN_HANDLE *conn_handle;
    CS_SERVERMSG *message;
#endif
{
fprintf(stderr,"%d: %s(%d)\n",__LINE__,message->text,message->msgnumber);
 if (message->msgnumber == 5701
 ||  message->msgnumber == 3701)
   return(CS_SUCCEED);
 DBErrorPending = TRUE;
 SQLCA_SqlCode = message->msgnumber;
 if (message->sqlstatelen > 0)
    strcpy(SQLCA_SqlState,message->sqlstate);
 sprintf (LastDBError, "SYB-Server Message:%ld, Severity:%ld, State:%d, Line:%ld, Server:%s Procedure:%s\n%s",
                       message->msgnumber,
                       message->severity,
                       message->state,
                       message->line,
                       (message->svrnlen)?message->svrname:"?",
                       (message->proclen)?message->proc:"?",
                       message->text);
 return(CS_SUCCEED);
}
CS_RETCODE CS_PUBLIC sybcsmsg_handler

#ifdef HAVE_PROTO
    (CS_CONTEXT *context, CS_CLIENTMSG *message)
#else
    (context, message)
    CS_CONTEXT *context;
    CS_CLIENTMSG *message;
#endif
{
fprintf(stderr,"%d\n",__LINE__);
 if (CS_SEVERITY(message->msgnumber) == CS_SV_INFORM)
    return(CS_SUCCEED);
 DBErrorPending = TRUE;
 SQLCA_SqlCode = message->msgnumber;
 if (message->sqlstatelen > 0)
    strcpy(SQLCA_SqlState,message->sqlstate);
 sprintf (LastDBError, "SYB-CS Message: Layer:%ld, Origin:%ld, Severity:%ld, Number:%ld, %s%s%s",
                       CS_LAYER(message->msgnumber), 
                       CS_ORIGIN(message->msgnumber),
                       CS_SEVERITY(message->msgnumber),
                       CS_NUMBER(message->msgnumber),
                       message->msgstring,
                       (message->osnumber==0)?"":"\n",
                       (message->osnumber==0)?"":message->osstring);
 return(CS_SUCCEED);
}

#include "rxsqlinc.h"
