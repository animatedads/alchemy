/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for MySQL
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
	{"INTEGER"   ,FIELD_TYPE_LONG         ,0},
	{"INT"       ,FIELD_TYPE_LONG         ,0},
	{"TINYINT"   ,FIELD_TYPE_CHAR         ,0},
	{"SMALLINT"  ,FIELD_TYPE_SHORT        ,0},
	{"MEDIUMINT" ,FIELD_TYPE_INT24        ,0},
	{"BIGINT"    ,FIELD_TYPE_LONGLONG     ,0},
	{"REAL"      ,FIELD_TYPE_DOUBLE       ,0},
	{"FLOAT"     ,FIELD_TYPE_FLOAT        ,0},
	{"DOUBLE"    ,FIELD_TYPE_DOUBLE       ,0},
	{"DECIMAL"   ,FIELD_TYPE_DECIMAL      ,0},
	{"VARCHAR"   ,FIELD_TYPE_VAR_STRING   ,0},
	{"CHAR"      ,FIELD_TYPE_STRING       ,0},
	{"TINYBLOB"  ,FIELD_TYPE_TINY_BLOB    ,0},
	{"BLOB"      ,FIELD_TYPE_BLOB         ,0},
	{"MEDIUMBLOB",FIELD_TYPE_MEDIUM_BLOB  ,0},
	{"LONGBLOB"  ,FIELD_TYPE_LONG_BLOB    ,0},
	{"TIME"      ,FIELD_TYPE_TIME         ,0},
	{"DATE"      ,FIELD_TYPE_DATE         ,0},
	{"DATETIME"  ,FIELD_TYPE_DATETIME     ,0},
	{"TIMESTAMP" ,FIELD_TYPE_TIMESTAMP    ,0},
#ifdef FIELD_TYPE_NEWDECIMAL
	{"DECIMAL"   ,FIELD_TYPE_NEWDECIMAL   ,0},
#endif
	{NULL        ,0                       ,0},
};

#endif
