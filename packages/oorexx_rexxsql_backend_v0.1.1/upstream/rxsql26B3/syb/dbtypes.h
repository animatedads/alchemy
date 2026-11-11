/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for Sybase System 10/11
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
	{"CHAR"        ,CS_CHAR_TYPE        ,0},
	{"BINARY"      ,CS_BINARY_TYPE      ,0},
	{"LONGCHAR"    ,CS_LONGCHAR_TYPE    ,0},
	{"LONGBINARY"  ,CS_LONGBINARY_TYPE  ,0},
	{"TEXT"        ,CS_TEXT_TYPE        ,0},
	{"IMAGE"       ,CS_IMAGE_TYPE       ,0},
	{"TINYINT"     ,CS_TINYINT_TYPE     ,0},
	{"SMALLINT"    ,CS_SMALLINT_TYPE    ,0},
	{"INT"         ,CS_INT_TYPE         ,0},
	{"REAL"        ,CS_REAL_TYPE        ,0},
	{"FLOAT"       ,CS_FLOAT_TYPE       ,0},
	{"BIT"         ,CS_BIT_TYPE         ,0},
	{"DATETIME"    ,CS_DATETIME_TYPE    ,0},
	{"DATETIME4"   ,CS_DATETIME4_TYPE   ,0},
	{"MONEY"       ,CS_MONEY_TYPE       ,0},
	{"MONEY4"      ,CS_MONEY4_TYPE      ,0},
	{"NUMERIC"     ,CS_NUMERIC_TYPE     ,0},
	{"DECIMAL"     ,CS_DECIMAL_TYPE     ,0},
	{"VARCHAR"     ,CS_VARCHAR_TYPE     ,0},
	{"VARBINARY"   ,CS_VARBINARY_TYPE   ,0},
	{"LONG"        ,CS_LONG_TYPE        ,0},
	{"SENSITIVITY" ,CS_SENSITIVITY_TYPE ,0},
	{"BOUNDARY"    ,CS_BOUNDARY_TYPE    ,0},
/*	{"VOID"        ,CS_VOID_TYPE        ,0},*/
	{NULL          ,0                   ,0},
};

#endif
