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
	{"VARCHAR2" ,ORA_VARCHAR2  ,0},
	{"NUMBER"   ,ORA_NUMBER    ,0},
	{"LONG RAW" ,ORA_LONGRAW   ,1},
	{"LONG"     ,ORA_LONG      ,1},
	{"UNKNOWN"  ,ORA_UNKNOWN   ,0},
	{"ROWID"    ,ORA_ROWID     ,0},
	{"DATE"     ,ORA_DATE      ,0},
	{"RAW"      ,ORA_RAW       ,0},
	{"CHAR"     ,ORA_CHAR      ,0},
	{"MLSLABEL" ,ORA_MLSLABEL  ,0},
	{NULL       ,0             ,0},
};

#endif
