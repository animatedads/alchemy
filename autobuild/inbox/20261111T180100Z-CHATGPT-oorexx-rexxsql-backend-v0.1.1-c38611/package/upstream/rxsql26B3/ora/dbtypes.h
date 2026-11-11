/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for Oracle
 ***********************************************************************
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling, 1994-1999.
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
#ifndef REXXSQL_DBTYPES_H
#define REXXSQL_DBTYPES_H

REXXSQL_DT datatype_conversion[] =
{
   {"VARCHAR2"                        ,SQLT_CHR          ,0},
   {"NUMBER"                          ,SQLT_NUM          ,0},
   {"LONG"                            ,SQLT_LNG          ,1},
   {"DATE"                            ,SQLT_DAT          ,0},
   {"RAW"                             ,SQLT_BIN          ,0},
   {"LONG RAW"                        ,SQLT_LBI          ,1},
   {"ROWID"                           ,SQLT_RDD          ,0},
   {"CHAR"                            ,SQLT_AFC          ,0},
   {"BINARY_FLOAT"                    ,SQLT_BFLOAT       ,0},
   {"BINARY_DOUBLE"                   ,SQLT_BDOUBLE      ,0},
   {"REF"                             ,SQLT_REF          ,0},
   {"CLOB"                            ,SQLT_CLOB         ,0},
   {"BLOB"                            ,SQLT_BLOB         ,0},
   {"BFILE"                           ,SQLT_FILE         ,0},
   {"TIMESTAMP"                       ,SQLT_TIMESTAMP    ,0},
   {"TIMESTAMP WITH TIME ZONE"        ,SQLT_TIMESTAMP_TZ ,0},
   {"INTERVAL YEAR TO MONTH"          ,SQLT_INTERVAL_YM  ,0},
   {"INTERVAL DAY TO SECOND"          ,SQLT_INTERVAL_DS  ,0},
   {"TIMESTAMP WITH LOCAL TIME ZONE"  ,SQLT_TIMESTAMP_LTZ,0},
   {NULL                              ,0                 ,0},
};

#endif
