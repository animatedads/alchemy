/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for SQLite
 ***********************************************************************
 *
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Mark Hessling, 1994-2006.
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
 * Mark Hessling  mark@rexx.org http://www.rexx.org
 *
 */
#ifndef REXXSQL_DBTYPES_H
#define REXXSQL_DBTYPES_H

REXXSQL_DT datatype_conversion[] =
{
	{"INTEGER PRIMARY KEY"      ,0 ,0},
	{"INTEGER"                  ,0 ,0},
	{"INT"                      ,0 ,0},
	{"FLOAT"                    ,0 ,0},
	{"NUMERIC"                  ,0 ,0},
	{"CHARACTER"                ,0 ,0},
	{"CHAR"                     ,0 ,0},
	{"TEXT"                     ,0 ,0},
	{"VARCHAR"                  ,0 ,0},
	{"BOOLEAN"                  ,0 ,0},
	{"BLOB"                     ,0 ,0},
	{"CLOB"                     ,0 ,0},
	{"TIMESTAMP"                ,0 ,0},
	{"DATETIME"                 ,0 ,0},
	{NULL                       ,0 ,0},
};
#endif
