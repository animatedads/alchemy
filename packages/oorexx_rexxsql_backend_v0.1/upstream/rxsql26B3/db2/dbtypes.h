/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for DB2
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
#ifdef SQL_BLOB
 {"BLOB",            SQL_BLOB,            1},
#endif
 {"CHAR",            SQL_CHAR,            0},
#ifdef SQL_CLOB
 {"CLOB",            SQL_CLOB,            0},
#endif
 {"DATE",            SQL_DATE,            0},
 {"DECIMAL",         SQL_DECIMAL,         0},
 {"DOUBLE",          SQL_DOUBLE,          0},
 {"FLOAT",           SQL_FLOAT,           0},
 {"GRAPHIC",         SQL_GRAPHIC,         0},
 {"INTEGER",         SQL_INTEGER,         0},
 {"LONGVARCHAR",     SQL_LONGVARCHAR,     1},
 {"LONGVARGRAPHIC",  SQL_LONGVARGRAPHIC,  1},
 {"NUMERIC",         SQL_NUMERIC,         0},
 {"REAL",            SQL_REAL,            0},
 {"SMALLINT",        SQL_SMALLINT,        0},
 {"TIME",            SQL_TIME,            0},
 {"TIMESTAMP",       SQL_TIMESTAMP,       0},
 {"VARCHAR",         SQL_VARCHAR,         0},
 {"VARGRAPHIC",      SQL_VARGRAPHIC,      1},
 {(char*)NULL,       0,                   0},
};

#endif
