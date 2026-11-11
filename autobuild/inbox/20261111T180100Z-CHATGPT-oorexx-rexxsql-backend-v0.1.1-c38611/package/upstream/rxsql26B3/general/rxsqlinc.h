/*
 * rxsqlinc.h - common routines for Rexx/SQL
 *
 *
 * REXX/SQL. A Rexx interface to SQL databases.
 * Copyright Mark Hessling, 1996-2002.
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
 */

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLCOMMIT( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLCOMMIT

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{ 
 return(SQLTRANSACT(name, argc, argv, stck, retstr,SQL_COMMIT));
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLROLLBACK( )
 *
 * RETURNS :  0-success, <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLROLLBACK

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{ 
 return(SQLTRANSACT(name, argc, argv, stck, retstr,SQL_ROLLBACK));
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLOPEN(statement-name [, <bind-args>])
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLOPEN

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 return(SQLEXEC(name, argc, argv, stck, retstr,1));
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLEXECUTE(statement-name [, <bind-args>])
 *
 * RETURNS :  0-success,
 *           >0-number of rows affected for SQLEXECUTE(),
 *           <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLEXECUTE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 return(SQLEXEC(name, argc, argv, stck, retstr,0));
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLVARIABLE( variable_name [,variable_value] )
 *
 * ARGUMENTS: 
 *            0 - variable_name
 *            1 - variable_value (if supplied, this is the new value)
 *
 * RETURNS :  Current value of "variable_name" or <0-error.
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLVARIABLE

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 char        opt_name[MAX_IDENTIFIER+1];
 SQLVAL      *opt=NULL;
 char        tmp[128];
 int         rc=0;
 RXSTRING    *rxs=NULL;
 ULONG       new_num=0L;

 FunctionPrologue((char*)name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc == 0 || argc > 2) return 1;

 if (RXSTRLEN(argv[0]) == 0)
    return ReturnError(retstr, 19, "null (\"\") variable name.");

 /* 
  * Get the name of the variable 
  */
 if ( (rc = MkIdentifier(argv[0], opt_name, sizeof(opt_name))) != 0 )
    return RxReturnNumber(retstr, (long)rc);

 /* 
  * Make sure the option is a valid one! 
  */
 if ((opt = ll_find(opt_tbl, opt_name)) == (SQLVAL*)NULL)
   {
    (void)sprintf(tmp,"unknown variable \"%s\".", opt_name);
    return ReturnError(retstr, 11, tmp);
   }

 /*
  * If the option is to set debugging level, we need to do more than
  * set a variable!
  */
 if (opt->valtype == SQLVAL_DEBUG)
 {
    if (argc == 1)
       return RxReturnNumber( retstr, RxGetRunFlags() );
    else
    {
       if (StrToInt(&argv[1], &new_num))
          return ReturnError(retstr, 7,"value is not a valid integer.");
       RxSetRunFlags( new_num );
       return RxReturnNumber(retstr, 0L);
    }
 }

 /*
  * If the option is to set debug trace file, we need to do more than
  * set a variable!
  */
 if (opt->valtype == SQLVAL_DEBUGFILE)
 {
    if (argc == 1)
       return RxReturnString( retstr, RxGetTraceFile() );
    else
    {
       if (RXSTRLEN(argv[1]) > MAX_PATH)
         {
          sprintf(tmp,"identifier is too long; max length is %d",MAX_IDENTIFIER);
          return ReturnError(retstr, 6,tmp);
         }
       RxSetTraceFile( RXSTRPTR(argv[1]) );
       return RxReturnNumber(retstr, 0L);
    }
 }

 if (argc == 1) 
   {
    if (opt->dtype == TYPE_INT
    ||  opt->dtype == TYPE_BOOL)
       return RxReturnNumber(retstr, *(ULONG*)(opt->value));
    else
       return RxReturnString(retstr, ((RXSTRING*)(opt->value))->strptr);
   }

 /* 
  * Must be updateable by user 
  */
 if (!opt->user_update) 
   {
    (void)sprintf(tmp, "variable \"%s\" is not settable.", opt_name);
    return ReturnError(retstr, 12, tmp);
   }

 /* 
  * Set the value of the option 
  */
 switch(opt->dtype)
   {
    case TYPE_INT:
         if (StrToInt(&argv[1], &new_num))
            return ReturnError(retstr, 7,"value is not a valid integer.");
         memcpy((ULONG*)opt->value,&new_num,sizeof(ULONG));
         break;
    case TYPE_BOOL:
         if (StrToBool(&argv[1], &new_num))
            return ReturnError(retstr, 97,"value is not a valid boolean.");
         memcpy((ULONG*)opt->value,&new_num,sizeof(ULONG));
         break;
    case TYPE_STRING:
         if (RXSTRLEN(argv[1]) > MAX_IDENTIFIER)
           {
            sprintf(tmp,"identifier is too long; max length is %d",MAX_IDENTIFIER);
            return ReturnError(retstr, 6,tmp);
           }
         rxs = (RXSTRING*)opt->value;
         RXSTRCPY(rxs->strptr,rxs->strlength,RXSTRPTR(argv[1]),RXSTRLEN(argv[1]));
         break;
    case TYPE_ARRAY:
         break;
   }

 return RxReturnNumber(retstr, 0L);
}

/*-----------------------------------------------------------------------------
 * SYNOPSIS:  SQLGETINFO( [connection_name],  variable_name [, stem_name)
 *
 * ARGUMENTS: 
 *            0 - connection_name (optional)
 *            1 - variable_name
 *            2 - stem_name (optional)
 *
 * RETURNS :  0-success, <0-error if argument 3 supplied
 *            or Current value of "variable_name" if argument 3 NOT supplied
 *----------------------------------------------------------------------------*/
RFH_RETURN_TYPE SQLGETINFO

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
 char     opt_name[MAX_IDENTIFIER+1];
 SQLVAL   *opt=NULL;
 char     tmp[128];
 int      rc=0,num_vars=0,i=0,len=0;
 RXSTRING *rxs=NULL;
 RXSTRING_DT *rxs_dt=NULL;
 DBCON    *db=NULL;
 char     varname[MAX_IDENTIFIER+1+10];
 char     dbname[MAX_IDENTIFIER+1];
 char     stem_name[MAX_IDENTIFIER+1];

 FunctionPrologue((char*)name, argc, argv);

 if (SQLCA_SqlCode) ClearDBError();
 if (SQLCA_IntCode) ClearIntError();

 if (argc > 3 || argc < 2) return 1;

 if ( (rc = MkIdentifier(argv[1], opt_name, sizeof(opt_name))) != 0 )
    return RxReturnNumber(retstr, (long)rc);
 if (argc == 3)
   {
    if ( (rc = MkIdentifier(argv[2], stem_name, sizeof(stem_name))) != 0 )
       return RxReturnNumber(retstr, rc);
    /*
     * If the stem name does NOT contain a trailing '.', error...
     */
    if (stem_name[strlen(stem_name)-1] != '.')
       return ReturnError(retstr, 91, "stem name MUST have trailing '.'");
   }
 /*
  * Find the variable in the connection table...
  */
 if (DbEnv == (DBENV*)NULL)
   {
    return ReturnError(retstr, 22, "no connections open.");
   }
 if (RXSTRLEN(argv[0])) 
   {
    /*
     * We have a named connection, get it...
     */
    if ( (rc = MkIdentifier(argv[0], dbname, sizeof(dbname))) != 0 )
       return RxReturnNumber(retstr, rc);
    /* 
     * Make sure the named connection exists. 
     */
    if ((db = FindObject(dbname, DbEnv->db_tbl, TBL_CONNECTIONS)) == (DBCON*)NULL) 
      {
       (void)sprintf(tmp,"connection \"%s\" is not open.", dbname);
       return ReturnError(retstr, 21, tmp);
      }
   }
 else
   {
    if (DbEnv->current_connection)
       db = DbEnv->current_connection;
    else
       return ReturnError(retstr, 25, "no connection is current");
    strcpy(dbname,db->name);
   }
 /* 
  * Make sure the option is a valid one! 
  */
 if ((opt = ll_find(db->db_opt, opt_name)) == (SQLVAL*)NULL)
   {
    (void)sprintf(tmp,"unknown variable \"%s\".", opt_name);
    return ReturnError(retstr, 11, tmp);
   }
 /*
  * If caller requires return as a string, get the variable's values
  * and return it.
  */
 if (argc == 2)
   {
    switch(opt->dtype)
      {
       case TYPE_INT:
       case TYPE_BOOL:
            return RxReturnNumber(retstr, *(ULONG*)(opt->value));
            break;
       case TYPE_STRING:
            return RxReturnString(retstr,((RXSTRING*)(opt->value))->strptr);
            break;
       case TYPE_ARRAY:
            rxs =(RXSTRING*)(opt->value);
            for (len=0,i=0;rxs[i].strlength;i++,len+=(rxs[i].strlength)+1);
            if (len > 256)
              {
               if ((retstr->strptr = (RXSTRING_STRPTR_TYPE)malloc(len)) == NULL)
                  return ReturnError(retstr, 10, "out of memory");
              }
            len = 0;
            for (i=0;rxs[i].strlength;i++)
              {
               memcpy(retstr->strptr+len,rxs[i].strptr,rxs[i].strlength);
               len += rxs[i].strlength;
               memcpy(retstr->strptr+len," ",1);
               len++;
              }
            len--;
            retstr->strptr[len] = '\0';
            retstr->strlength = len;
            return (0);
            break;
       case TYPE_DATATYPE:
            len = 0;
            rxs_dt =(RXSTRING_DT*)(opt->value);
            if (rxs_dt != NULL)
            {
               for (len=0,i=0;rxs_dt[i].strlength;i++,len+=(rxs_dt[i].strlength)+1);
               if (len > 256)
               {
                  if ((retstr->strptr = (RXSTRING_STRPTR_TYPE)malloc(len)) == NULL)
                     return ReturnError(retstr, 10, "out of memory");
               }
               len = 0;
               for (i=0;rxs_dt[i].strlength;i++)
               {
                  memcpy(retstr->strptr+len,rxs_dt[i].strptr,rxs_dt[i].strlength);
                  len += rxs_dt[i].strlength;
                  memcpy(retstr->strptr+len," ",1);
                  len++;
               }
               len--;
            }
            retstr->strptr[len] = '\0';
            retstr->strlength = len;
            return (0);
            break;
      }
   }
 /*
  * To reach here the caller supplied a stem name. Use it to generate
  * a REXX array.
  */
 switch(opt->dtype)
   {
    case TYPE_INT:
    case TYPE_BOOL:
         (void)sprintf(varname, "%s%u", stem_name, 1);
         sprintf(tmp,"%lu",*(ULONG*)(opt->value));
         num_vars = 1;
         rc = SetRexxVariable(varname, strlen(varname), tmp, strlen(tmp));
         break;
    case TYPE_STRING:
         (void)sprintf(varname, "%s%u", stem_name, 1);
         num_vars = 1;
         rc = SetRexxVariable(varname, strlen(varname), 
                       ((RXSTRING*)(opt->value))->strptr,
                       (size_t)(((RXSTRING*)(opt->value))->strlength));
         break;
    case TYPE_ARRAY:
         rxs =(RXSTRING*)(opt->value);
         for (i=0;;i++)
           {
            if (rxs[i].strlength == 0)
               break;
            (void)sprintf(varname, "%s%u", stem_name, i+1);
            rc = SetRexxVariable(varname, strlen(varname), rxs[i].strptr,rxs[i].strlength);
           }
         num_vars = i;
         break;
    case TYPE_DATATYPE:
         rxs_dt =(RXSTRING_DT*)(opt->value);
         if (rxs_dt)
         {
            for (i=0;;i++)
            {
               if (rxs_dt[i].strlength == 0)
                  break;
               (void)sprintf(varname, "%s%u", stem_name, i+1);
               rc = SetRexxVariable(varname, strlen(varname), rxs_dt[i].strptr,rxs_dt[i].strlength);
            }
         }
         else
         {
            i = 1;
            (void)sprintf(varname, "%s%u", stem_name, i);
            rc = SetRexxVariable(varname, strlen(varname), "*** not supported ***",21);
         }
         num_vars = i;
         break;
   }
 if (!rc)
   {
    (void)sprintf(varname, "%s0", stem_name);
    sprintf(tmp,"%u",num_vars);
    rc = SetRexxVariable(varname, strlen(varname), tmp, strlen(tmp));
   }

 return RxReturnNumber(retstr, rc);
}

/*-----------------------------------------------------------------------------
 * Declare the initiating and terminating functions when used as a dynamic lib
 *----------------------------------------------------------------------------*/

/*
 * SYNOPSIS: SQLLOADFUNCS();
 */
RFH_RETURN_TYPE SQLLOADFUNCS

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
   ULONG rc=0;

   if ( my_checkparam(NAME_SQLLOADFUNCS_INT,argc, 0, 0 ) )
      return( 1 );
#if defined(DYNAMIC_LIBRARY)
   rc = InitRxPackage( NULL );
   if ( !QueryRxFunction( NAME_SQLCONNECT_EXT ) )
   {
      /*
       * Register all external functions
       */
      if ( !rc )
         rc = RegisterRxFunctions( );
   }
   RxSetRunFlags( 0 );
#endif
   return RxReturnNumber( retstr, rc );
}

/*
 * SYNOPSIS: SQLDROPFUNCS(["UNLOAD"]);
 */
RFH_RETURN_TYPE SQLDROPFUNCS

#ifdef HAVE_PROTO
    (RFH_ARG0_TYPE		name,RFH_ARG1_TYPE	argc,RFH_ARG2_TYPE	argv,RFH_ARG3_TYPE		stck,RFH_ARG4_TYPE	retstr)
#else
    (name, argc, argv, stck, retstr)
    RFH_ARG0_TYPE		name;
    RFH_ARG1_TYPE	argc;
    RFH_ARG2_TYPE	argv;
    RFH_ARG3_TYPE		stck;
    RFH_ARG4_TYPE	retstr;
#endif
{
   int rc=0;
   int unload=0;

   FunctionPrologue( ( char* )name, argc, argv );

   if ( my_checkparam(NAME_SQLDROPFUNCS_INT,argc, 0, 1 ) )
      return( 1 );
   if ( argv[0].strlength == 6
   &&   memcmpi( argv[0].strptr, "UNLOAD", 6 ) == 0 )
      unload = 1;
   rc = TermRxPackage( RxPackageName, unload );
   return RxReturnNumber( retstr, rc );
}

/*-----------------------------------------------------------------------------
 * Set up the Version String
 *----------------------------------------------------------------------------*/
static void *SetVersion

#if HAVE_PROTO
    (void *db)
#else
    (db)
    void *db;
#endif

{
 InternalTrace("SetVersion", "%x", db );
 sprintf(RexxSqlVersionString,"%s %s %s %s %s",
                              RxPackageName,
                              REXXSQL_VERSION,
                              REXXSQL_DATE,
                              CURRENT_OS,
                              CURRENT_DB);
 MAKERXSTRING(RexxSqlVersion, RexxSqlVersionString,(ULONG)strlen(RexxSqlVersionString));
 return((void*)&RexxSqlVersion);
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SetDebugFile

#if HAVE_PROTO
    (void *db)
#else
    (db)
    void *db;
#endif
{

 InternalTrace("SetDebugFile", "%x", db );

 strcpy(DebugFile,DEBUGFILE);
 MAKERXSTRING(RXSDebugFile,DebugFile,(ULONG)strlen(DebugFile));
 return((void*)&RXSDebugFile);
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SetNullStringIn

#if HAVE_PROTO
    (void *db)
#else
    (db)
    void *db;
#endif
{

 InternalTrace("SetNullStringIn", "%x", db );

 strcpy(NullStringIn,NULLSTRINGIN);
 MAKERXSTRING(RXSNullStringIn,NullStringIn,(ULONG)strlen(NullStringIn));
 return((void*)&RXSNullStringIn);
}

/*-----------------------------------------------------------------------------
 * Set up the string representing a NULL value
 *----------------------------------------------------------------------------*/
static void *SetNullStringOut

#if HAVE_PROTO
    (void *db)
#else
    (db)
    void *db;
#endif

{

 InternalTrace("SetNullStringOut", "%x", db );

 strcpy(NullStringOut,NULLSTRINGOUT);
 MAKERXSTRING(RXSNullStringOut,NullStringOut,(ULONG)strlen(NullStringOut));
 return((void*)&RXSNullStringOut);
}

/*-----------------------------------------------------------------------------
 * Install all REXX/SQL variable structures.
 *----------------------------------------------------------------------------*/
void *GetSqlVariableValue

#ifdef HAVE_PROTO
    (int type, void *idb)
#else
    (type,idb)
    int type;
    void *idb;
#endif

{
 void *result=NULL;
 DBCON *db=idb;

 InternalTrace("GetSqlVariableValue", "%d,%x", type, idb );

 switch (type)
   {
    case SQLVAL_DEBUGFILE:
         result = SetDebugFile(NULL);
         break;
    case SQLVAL_NULLSTRINGIN:
         result = SetNullStringIn(NULL);
         break;
    case SQLVAL_NULLSTRINGOUT:
         result = SetNullStringOut(NULL);
         break;
    case SQLVAL_VERSION:
         result = SetVersion(NULL);
         break;
    case SQLVAL_SUPPORTSTRANSACTIONS:
         result = SetSupportsTransactions(db);
         break;
    case SQLVAL_SUPPORTSSQLGETDATA:
         result = SetSupportsSqlGetData(db);
         break;
    case SQLVAL_DESCRIBECOLUMNS:
         result = SetDescribeColumns(db);
         break;
    case SQLVAL_DATATYPES:
         result = SetDatatypes(db);
         break;
    case SQLVAL_DBMSNAME:
         result = SetDBMSName(db);
         break;
    case SQLVAL_DBMSVERSION:
         result = SetDBMSVer(db);
         break;
   }
 return (result);
}

/*-----------------------------------------------------------------------------
 * Install all REXX/SQL variable structures.
 *----------------------------------------------------------------------------*/
int InstallSQLVariables

#ifdef HAVE_PROTO
    (void)
#else
    ()
#endif

{
 int     rc=0,i=0;
 SQLVAL  *curr=NULL;
 void    *result=NULL;

 InternalTrace("InstallSQLVariables", NULL );

 for (i=0;strlen(sqlvariable_vars[i].name)!=0;i++)
   {
    if (sqlvariable_vars[i].value)
       result = sqlvariable_vars[i].value;
    else
       result = GetSqlVariableValue(sqlvariable_vars[i].valtype,NULL);
    if ((curr = InstallSQLVariable(
                &rc,
                sqlvariable_vars[i].name,
                opt_tbl,
                sqlvariable_vars[i].user_update, 
                sqlvariable_vars[i].dtype, 
                0, 
                sqlvariable_vars[i].option,
                result,
                sqlvariable_vars[i].valtype)) == NULL)
       return(rc);
    if (opt_tbl == NULL)
       opt_tbl = curr;
   }
 return (0);
}

/*-----------------------------------------------------------------------------
 * Validates datatype string
 *----------------------------------------------------------------------------*/
static int ValidateDataType

#ifdef HAVE_PROTO
    (char *buf, int len, DBCON *db)
#else
    (buf, len, db)
    char          *buf;
    int           len;
    DBCON         *db;
#endif
{
 int         i=0;
 SQLVAL      *opt=NULL;
 RXSTRING_DT *rxs_dt=NULL;

 InternalTrace("ValidateDatatype", "%s,%d,%x", buf, len, db );

 /*
  * Find the internal datatype represenation for the supplied
  * datatype string. If not found, return -1.
  */
 if ((opt = ll_find(db->db_opt, "DATATYPES")) == (SQLVAL*)NULL)
    return (RXSQL_INVALID_DATATYPE);
 rxs_dt =(RXSTRING_DT*)(opt->value);
 for (i=0;rxs_dt[i].strlength;i++)
   {
    if (len == rxs_dt[i].strlength
    &&  memcmpi(rxs_dt[i].strptr,buf,len) == 0)
       return(rxs_dt[i].internal);
   }
 return(RXSQL_INVALID_DATATYPE);
}

/***********************************************************************/
RSH_RETURN_TYPE PackageSubcomHandler

#if defined(HAVE_PROTO)
   (
   RSH_ARG0_TYPE Command,    /* Command string passed from the caller    */
   RSH_ARG1_TYPE Flags,      /* pointer to short for return of flags     */
   RSH_ARG2_TYPE Retstr)     /* pointer to RXSTRING for RC return        */
#else
   ( Command, Flags, Retstr )
   RSH_ARG0_TYPE Command;    /* Command string passed from the caller    */
   RSH_ARG1_TYPE Flags;      /* pointer to short for return of flags     */
   RSH_ARG2_TYPE Retstr;     /* pointer to RXSTRING for RC return        */
#endif
/***********************************************************************/
{
   /*
    * Leave the Flags variable alone indicating we want to
    * use the default subcommand handler.
    */
   *Flags = *Flags;
   return 0;
}

/*
 * These functions used by loader.c to obtain package-specific info
 */
int RexxSQLInitialiser( RxPackageGlobalDataDef *MyGlob )
{
   RexxSQLData.RxPackageGlobalData = MyGlob;
   return 0;
}

RexxSubcomHandler *getRexxSQLSubcomHandler( void )
{
   return NULL;
}

RexxFunction *getRexxSQLFunctions( void )
{
   return RexxSQLFunctions;
}

PackageInitialiser *getRexxSQLInitialiser( void )
{
   return RexxSQLInitialiser;
}

PackageTerminator *getRexxSQLTerminator( void )
{
   return NULL;
}
