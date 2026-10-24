/***********************************************************************
 * dbheader.h - include database and platform specific header file
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

#ifndef REXXSQL_DBHEADER_H
#define REXXSQL_DBHEADER_H

#if defined(__OS2__)
# if defined(__EMX__)
#  define OS2DEF_INCLUDED
# endif
# include <os2odbc.h>
#endif

#if defined(__WATCOMC__) && defined(__NT__)
# include <ntodbc.h>
#endif

#if defined(__WATCOMC__) && defined(__WINDOWS__)
# include <winodbc.h>
#endif

#if defined(_MSC_VER) && defined(WIN32)
# include <windows.h>
# include <ntodbc.h>
#endif

#if defined(UNIX)
# include <unixodbc.h>
#endif

#endif
