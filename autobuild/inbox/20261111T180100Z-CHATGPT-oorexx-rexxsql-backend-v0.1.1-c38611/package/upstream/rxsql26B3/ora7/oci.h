/***********************************************************************/
/* oci.h - REXX/SQL for Oracle                                         */
/***********************************************************************/
/*
 * REXX/SQL. A REXX interface to SQL databases.
 * Copyright Impact Systems Pty Ltd, 1994-1996.
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
 * Author:  Chris O'Sullivan  Ph (Australia) 015 123414
 *
 * Header file for ORACLE Call Interface
 *
 * Defines structures CURSOR, SQLWA etc.
 *
 */

#define V2ERRORCODE(cursor)   ((cursor)->csrrc)
#define V4ERRORCODE(cursor)   ((cursor)->csrarc)
#define SQLROWCNT(cursor)     ((cursor)->csrrpc)
#define SQLERRPOS(cursor)     ((cursor)->csrpeo)

#define NO_DATA_FOUND      4     /* V2 return code */

#define MAX_COLS        254
#define MAX_NAMELEN      30
#define MAX_BINDVARS    256

#define ORA_DATE_LEN      9     /* DD-MON-YY */
#define ORA_LONG_LEN    (32 * 1024 - 1)   /* Limited by odefin() */

#if SIZEOF_LONG == 8
# define SIZEOF_HDA     512   /* define Host Data Area (HDA) size */
# define BYTE4    int
#else
# define SIZEOF_HDA     256   /* define Host Data Area (HDA) size */
# define BYTE4    long
#endif

/* These are defined in the new Oracle7 header files! Should be converted */
#if HAVE_PROTO
typedef          int   eword;
typedef signed   int   sword;
typedef unsigned int   uword;
typedef          char  eb1;
typedef signed   char  sb1;
typedef unsigned char  ub1;
typedef          short eb2;
typedef signed   short sb2;
typedef unsigned short ub2;
typedef          BYTE4 eb4;
typedef signed   BYTE4 sb4;
typedef unsigned BYTE4 ub4;
typedef unsigned char  text;
#else
typedef          int   eword;
typedef          int   sword;
typedef unsigned int   uword;
typedef          char  eb1;
typedef          char  sb1;
typedef unsigned char  ub1;
typedef          short eb2;
typedef          short sb2;
typedef unsigned short ub2;
typedef          BYTE4 eb4;
typedef          BYTE4 sb4;
typedef unsigned BYTE4 ub4;
typedef unsigned char  text;
#endif


/*
 * ORACLE external datatypes (used for input/output to Oracle)
 */
#define EXT_VARCHAR2  1 /* External CHAR datatype */
#define EXT_LONGRAW  24 /* External LONG RAW datatype */
#define EXT_LONG      8 /* External LONG datatype */

/*
 * ORACLE internal datatypes
 */
#define ORA_VARCHAR2   1 /* Internal VARCHAR2 datatype */
#define ORA_NUMBER     2 /* Internal NUMBER datatype */
#define ORA_LONG       8 /* Internal LONG datatype */
#define ORA_UNKNOWN   10 /* Datatype unknown until after binding */
#define ORA_ROWID     11 /* Internal ROWID */
#define ORA_DATE      12 /* Internal DATE datatype */
#define ORA_RAW       23 /* Internal RAW datatype */
#define ORA_LONGRAW   24 /* Internal LONG RAW datatype */
#define ORA_CHAR      96 /* Internal ANSI compatible CHAR datatype */
#define ORA_MLSLABEL 106 /* Internal MLSLABEL datatype */

/*
 *
 * Define the C version of the CDA header
 */
struct cda_head
{
   sb2   csrrc;               /* return code */
   ub2   csrft;               /* function type */
   ub4   csrrpc;              /* rows processed count */
   ub2   csrpeo;              /* parse error offset */
   ub1   csrfc;               /* function code */
   ub1   csrfil;              /* filler  */
   ub2   csrarc;              /* V4 error code */
   ub1   csrwrn;              /* warning flags */
   ub1   csrflg;              /* error flags */
   /********************* Operating system dependent *********************/
   unsigned int csrcn;        /* cursor number */
   struct
   {                          /* rowid structure */
      struct
      {
         ub4   tidtrba;       /* rba of 1st blockof table */
         ub2   tidpid;        /* partition id of table */
         ub1   tidtbl;        /* table id of table */
      } ridtid;
      ub4   ridbrba;          /* rba of datablock */
      ub2   ridsqn;           /* sequence number of row in block */
   } csrrid;
   unsigned int csrose;       /* os dependent error code */
   ub1   csrchk;              /* check byte */
   void  *res;                /* reserved area */
};

#define CDA_SIZE 64
/*
 *
 * Define the C version of the CURSOR (for 32 & 64 bit machines)
 */
typedef struct {
   sb2      csrrc;                      /* return code */
   ub2      csrft;                 /* function type */
   ub4   csrrpc;              /* rows processed count */
   ub2      csrpeo;                /* parse error offset */
   ub1   csrfc;                 /* function code */
   ub1   csrfil;                      /* filler  */
   ub2   csrarc;                     /* V4 error code */
   ub1   csrwrn;                /* warning flags */
   ub1   csrflg;                  /* error flags */
   /********************* Operating system dependent *********************/
   unsigned int      csrcn;                 /* cursor number */
   struct {                     /* rowid structure */
      struct {
         ub4   tidtrba;  /* rba of 1st blockof table */
         ub2   tidpid;      /* partition id of table */
         ub1   tidtbl;          /* table id of table */
      } ridtid;
      ub4   ridbrba;           /* rba of datablock */
      ub2   ridsqn;     /* sequence number of row in block */
   } csrrid;
   unsigned int      csrose;                /* os dependent error code */
   ub1   csrchk;                   /* check byte */
   void  *res; /* reserved area */
   ub1   crsfill[CDA_SIZE-sizeof(struct cda_head)];     /* private, reserved fill originally was 26 now 30*/
} CURSOR;


/*
 * Definition of parameter markers
 */
typedef struct
{
 ub1  *buf;     /* Pointer to buffer containing parameter marker value */
 long valuelen;                                /* Actual length of buf */
 long buflen;                               /* Length of allocated buf */
} PMDSCR;

typedef struct {
   sb4   rbufl;         /* Size of buffer to hold fetched column value */
   sb4   cbufl;      /* Length of column name - reset to actual length */
   sb2   rcode;         /* Column return code - valid only after fetch */
   sb2   dbtype;                           /* Internal Oracle datatype */
   sb2   retl;                               /* Return length of field */
   sb2   indp;               /* Indicator for field - after each fetch */
                   /* <0 - NULL; 0 - OK; >0 - length BEFORE truncation */
   sb2   prec;                         /* Precision of number datatype */
   sb2   scale;                            /* Scale of number datatype */
   sb2   nullok;                 /* Are nulls permitted? 0=no, <>0=yes */
   ub1   *rbuf;      /* Pointer to buffer to hold fetched column value */
#if 0
   ub1   cbuf[MAX_NAMELEN+1];            /* Buffer to hold column name */
#else
   ub1   *cbuf;            /* Buffer to hold column name */
#endif
} FLDDSCR;


#if HAVE_PROTO
sword obndrn(CURSOR*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword);
sword obndrv(CURSOR*,text*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword);
sword oclose(CURSOR*);
sword ocom(CURSOR*);
sword ocan(CURSOR*);
sword odescr(CURSOR*,sword,sb4*,sb2*,sb1*,sb4*,sb4*,sb2*,sb2*,sb2*);
sword odefin(CURSOR*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword,ub2*,ub2*);
sword oerhms(CURSOR*,sb2,text*,sword);
sword oexec(CURSOR*);
sword ofetch(CURSOR*);
sword oflng (CURSOR*,sword,ub1*,sb4,sword,ub4*,sb4);
sword ologof(CURSOR*);
sword oopen(CURSOR*,CURSOR*,text*,sword,sword,text*,sword);
sword oparse(CURSOR*,text*,sb4,sword,ub4);
sword orlon(CURSOR*,ub1*,text*,sword,text*,sword,sword);
sword orol(CURSOR*);
sword osql3(CURSOR*,text*,sword);
#else
sword obndrn(/*CURSOR*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword*/);
sword obndrv(/*CURSOR*,text*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword*/);
sword oclose(/*CURSOR**/);
sword ocom(/*CURSOR**/);
sword ocan(/*CURSOR**/);
sword odescr(/*CURSOR*,sword,sb4*,sb2*,sb1*,sb4*,sb4*,sb2*,sb2*,sb2**/);
sword odefin(/*CURSOR*,sword,ub1*,sword,sword,sword,sb2*,text*,sword,sword,ub2*,ub2**/);
sword oerhms(/*CURSOR*,sb2,text*,sword*/);
sword oexec(/*CURSOR**/);
sword ofetch(/*CURSOR**/);
sword oflng (/*CURSOR*,sword,ub1*,sb4,sword,ub4*,sb4*/);
sword ologof(/*CURSOR**/);
sword oopen(/*CURSOR*,CURSOR*,text*,sword,sword,text*,sword*/);
sword oparse(/*CURSOR*,text*,sb4,sword,ub4*/);
sword orlon(/*CURSOR*,ub1*,text*,sword,text*,sword,sword*/);
sword orol(/*CURSOR**/);
sword osql3(/*CURSOR*,text*,sword*/);
#endif
