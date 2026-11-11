/***********************************************************************
 * dbtypes.h - REXX/SQL datatypes for easysoft ODBC-ODBC bridge
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
#ifdef SQL_BIGINT
 {"BIGINT",          SQL_BIGINT,          0},
#endif
#ifdef SQL_BINARY
 {"BINARY",          SQL_BINARY,          1},
#endif
#ifdef SQL_BIT
 {"BIT",             SQL_BIT,             0},
#endif
#ifdef SQL_BLOB
 {"BLOB",            SQL_BLOB,            1},
#endif
#ifdef SQL_CHAR
 {"CHAR",            SQL_CHAR,            0},
#endif
#ifdef SQL_CLOB
 {"CLOB",            SQL_CLOB,            0},
#endif
#ifdef SQL_DATE
 {"DATE",            SQL_DATE,            0},
#endif
#ifdef SQL_DATETIME
 {"DATETIME",        SQL_DATETIME,        0},
#endif
#ifdef SQL_DECIMAL
 {"DECIMAL",         SQL_DECIMAL,         0},
#endif
#ifdef SQL_DOUBLE
 {"DOUBLE",          SQL_DOUBLE,          0},
#endif
#ifdef SQL_FLOAT
 {"FLOAT",           SQL_FLOAT,           0},
#endif
#ifdef SQL_GRAPHIC
 {"GRAPHIC",         SQL_GRAPHIC,         0},
#endif
#ifdef SQL_GUID
 {"GUID",            SQL_GUID,            0},
#endif
#ifdef SQL_INTEGER
 {"INTEGER",         SQL_INTEGER,         0},
#endif
#ifdef SQL_LONGVARBINARY
 {"LONGVARBINARY",   SQL_LONGVARBINARY,   1},
#endif
#ifdef SQL_LONGVARCHAR
 {"LONGVARCHAR",     SQL_LONGVARCHAR,     1},
#endif
#ifdef SQL_LONGVARGRAPHIC
 {"LONGVARGRAPHIC",  SQL_LONGVARGRAPHIC,  1},
#endif
#ifdef SQL_NUMERIC
 {"NUMERIC",         SQL_NUMERIC,         0},
#endif
#ifdef SQL_REAL
 {"REAL",            SQL_REAL,            0},
#endif
#ifdef SQL_SMALLINT
 {"SMALLINT",        SQL_SMALLINT,        0},
#endif
#ifdef SQL_TIME
 {"TIME",            SQL_TIME,            0},
#endif
#ifdef SQL_TIMESTAMP
 {"TIMESTAMP",       SQL_TIMESTAMP,       0},
#endif
#ifdef SQL_TINYINT
 {"TINYINT",         SQL_TINYINT,         0},
#endif
#ifdef SQL_VARBINARY
 {"VARBINARY",       SQL_VARBINARY,       1},
#endif
#ifdef SQL_VARCHAR
 {"VARCHAR",         SQL_VARCHAR,         0},
#endif
#ifdef SQL_VARGRAPHIC
 {"VARGRAPHIC",      SQL_VARGRAPHIC,      1},
#endif
 {(char*)NULL,       0,                   0},
};

#endif
