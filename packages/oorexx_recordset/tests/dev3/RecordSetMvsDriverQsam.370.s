         COPY  PDPTOP
         CSECT
* Program text area
@@LC0    EQU   *
         DC    X'0'
         DS    0F
* Function set_error,F1 prologue
@@F1     PDPPRLG CINDEX=0,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN0
         LTORG
@@FEN0   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG0    EQU   *
         LR    11,1
         L     10,=A(@@PGT0)
* Function set_error code
         L     2,0(11)
         LTR   2,2
         BE    @@L1
         L     2,4(11)
         LTR   2,2
         BNE   @@L2
         B     @@L1
@@L2     EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BNE   @@L4
         MVC   8(4,11),=A(@@LC0)
@@L4     EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'0'
@@L5     EQU   *
         L     2,88(13)
         A     2,=F'1'
         CL    2,4(11)
         BNL   @@L6
         L     2,8(11)
         A     2,88(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L6
         L     2,0(11)
         A     2,88(13)
         L     3,8(11)
         A     3,88(13)
         MVC   0(1,2),0(3)
         L     2,88(13)
         A     2,=F'1'
         ST    2,88(13)
         B     @@L5
@@L6     EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,88(13)
         MVI   0(2),0
@@L1     EQU   *
         L     12,0(,10)
* Function set_error epilogue
         PDPEPIL
* Function set_error literal pool
         DS    0F
         LTORG
* Function set_error page table
         DS    0F
@@PGT0   EQU   *
         DC    A(@@PG0)
         DS    0F
* Function copy_text,F2 prologue
@@F2     PDPPRLG CINDEX=1,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN1
         LTORG
@@FEN1   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG1    EQU   *
         LR    11,1
         L     10,=A(@@PGT1)
* Function copy_text code
         L     2,0(11)
         LTR   2,2
         BE    @@L7
         L     2,4(11)
         LTR   2,2
         BNE   @@L8
         B     @@L7
@@L8     EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'0'
         L     2,8(11)
         LTR   2,2
         BE    @@L10
@@L11    EQU   *
         L     2,88(13)
         A     2,=F'1'
         CL    2,4(11)
         BNL   @@L10
         L     2,8(11)
         A     2,88(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L10
         L     2,0(11)
         A     2,88(13)
         L     3,8(11)
         A     3,88(13)
         MVC   0(1,2),0(3)
         L     2,88(13)
         A     2,=F'1'
         ST    2,88(13)
         B     @@L11
@@L10    EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,88(13)
         MVI   0(2),0
@@L7     EQU   *
         L     12,0(,10)
* Function copy_text epilogue
         PDPEPIL
* Function copy_text literal pool
         DS    0F
         LTORG
* Function copy_text page table
         DS    0F
@@PGT1   EQU   *
         DC    A(@@PG1)
         DS    0F
* Function map_qsam_status,F3 prologue
@@F3     PDPPRLG CINDEX=2,FRAME=112,BASER=12,ENTRY=NO
         B     @@FEN2
         LTORG
@@FEN2   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG2    EQU   *
         LR    11,1
         L     10,=A(@@PGT2)
* Function map_qsam_status code
         L     2,0(11)
         LTR   2,2
         BNE   @@L14
         MVC   88(4,13),4(11)
         MVC   92(4,13),8(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   104(4,13),=F'0'
         B     @@L13
@@L14    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,4(0,0)
         CLR   2,3
         BNE   @@L15
         MVC   88(4,13),4(11)
         MVC   92(4,13),8(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   104(4,13),=F'1'
         B     @@L13
@@L15    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,12(0,0)
         CLR   2,3
         BNE   @@L16
         MVC   88(4,13),4(11)
         MVC   92(4,13),8(11)
         MVC   96(4,13),12(11)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   104(4,13),=F'3'
         B     @@L13
@@L16    EQU   *
         L     12,0(,10)
         MVC   88(4,13),4(11)
         MVC   92(4,13),8(11)
         MVC   96(4,13),12(11)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   104(4,13),=F'4'
@@L13    EQU   *
         L     12,0(,10)
         L     15,104(13)
* Function map_qsam_status epilogue
         PDPEPIL
* Function map_qsam_status literal pool
         DS    0F
         LTORG
* Function map_qsam_status page table
         DS    0F
@@PGT2   EQU   *
         DC    A(@@PG2)
@@LC1    EQU   *
         DC    C'QSAM open requires request, handle and info'
         DC    X'0'
@@LC2    EQU   *
         DC    C'QSAM dev3 opens caller-allocated DD resources on'
         DC    C'ly'
         DC    X'0'
@@LC3    EQU   *
         DC    C'Invalid QSAM RecordSet mode'
         DC    X'0'
@@LC4    EQU   *
         DC    C'QSAM driver handle allocation failed'
         DC    X'0'
@@LC5    EQU   *
         DC    C'MVS QSAM OPEN failed'
         DC    X'0'
@@LC6    EQU   *
         DC    C'PS'
         DC    X'0'
@@LC7    EQU   *
         DC    C'FB'
         DC    X'0'
@@LC8    EQU   *
         DC    C'F'
         DC    X'0'
@@LC9    EQU   *
         DC    C'VB'
         DC    X'0'
@@LC10   EQU   *
         DC    C'V'
         DC    X'0'
@@LC11   EQU   *
         DC    C'U'
         DC    X'0'
@@LC12   EQU   *
         DC    C'UNKNOWN'
         DC    X'0'
         DS    0F
* X-func mvsrs_driver_open prologue
MVSRS@DR PDPPRLG CINDEX=3,FRAME=152,BASER=12,ENTRY=YES
         B     @@FEN3
         LTORG
@@FEN3   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG3    EQU   *
         LR    11,1
         L     10,=A(@@PGT3)
* Function mvsrs_driver_open code
         L     2,4(11)
         LTR   2,2
         BE    @@L18
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L18    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L20
         L     2,4(11)
         LTR   2,2
         BE    @@L20
         L     2,8(11)
         LTR   2,2
         BNE   @@L19
@@L20    EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC1)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   136(4,13),=F'4'
         B     @@L17
@@L19    EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,0(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L22
         L     2,0(11)
         L     2,8(2)
         LTR   2,2
         BE    @@L22
         L     2,0(11)
         L     2,8(2)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L21
@@L22    EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC2)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   136(4,13),=F'3'
         B     @@L17
@@L21    EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,4(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L23
         MVC   128(4,13),=F'1'
         B     @@L24
@@L23    EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,4(2)
         LA    3,2(0,0)
         CLR   2,3
         BNE   @@L25
         MVC   128(4,13),=F'2'
         B     @@L24
@@L25    EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,4(2)
         LA    3,3(0,0)
         CLR   2,3
         BNE   @@L27
         MVC   128(4,13),=F'3'
         B     @@L24
@@L27    EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC3)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   136(4,13),=F'4'
         B     @@L17
@@L24    EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'1'
         MVC   92(4,13),=F'20'
         LA    1,88(,13)
         L     15,=V(CALLOC)
         BALR  14,15
         LR    2,15
         ST    2,104(13)
         L     2,104(13)
         LTR   2,2
         BNE   @@L29
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC4)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   136(4,13),=F'4'
         B     @@L17
@@L29    EQU   *
         L     12,0(,10)
         L     2,104(13)
         A     2,=F'8'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         L     2,0(11)
         MVC   96(4,13),8(2)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         L     3,104(13)
         L     2,0(11)
         MVC   4(4,3),4(2)
         MVC   112(4,13),=F'0'
         MVC   116(4,13),=F'0'
         MVC   120(4,13),=F'0'
         L     2,104(13)
         A     2,=F'8'
         ST    2,88(13)
         MVC   92(4,13),128(13)
         MVC   96(4,13),104(13)
         LA    2,112(,13)
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=V(RQOPEN)
         BALR  14,15
         LR    2,15
         ST    2,132(13)
         L     2,132(13)
         LTR   2,2
         BE    @@L30
         MVC   88(4,13),104(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   88(4,13),132(13)
         MVC   92(4,13),12(11)
         MVC   96(4,13),16(11)
         MVC   100(4,13),=A(@@LC5)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         ST    2,136(13)
         B     @@L17
@@L30    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),=F'9'
         MVC   96(4,13),=A(@@LC6)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         L     2,120(13)
         N     2,=F'192'
         LA    3,128(0,0)
         CLR   2,3
         BNE   @@L31
         L     2,8(11)
         A     2,=F'9'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         L     2,120(13)
         N     2,=F'16'
         LTR   2,2
         BE    @@L32
         MVC   140(4,13),=A(@@LC7)
         B     @@L33
@@L32    EQU   *
         L     12,0(,10)
         MVC   140(4,13),=A(@@LC8)
@@L33    EQU   *
         L     12,0(,10)
         MVC   96(4,13),140(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         B     @@L34
@@L31    EQU   *
         L     12,0(,10)
         L     2,120(13)
         N     2,=F'192'
         LA    3,64(0,0)
         CLR   2,3
         BNE   @@L35
         L     2,8(11)
         A     2,=F'9'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         L     2,120(13)
         N     2,=F'16'
         LTR   2,2
         BE    @@L36
         MVC   144(4,13),=A(@@LC9)
         B     @@L37
@@L36    EQU   *
         L     12,0(,10)
         MVC   144(4,13),=A(@@LC10)
@@L37    EQU   *
         L     12,0(,10)
         MVC   96(4,13),144(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         B     @@L34
@@L35    EQU   *
         L     12,0(,10)
         L     2,120(13)
         N     2,=F'192'
         LA    3,192(0,0)
         CLR   2,3
         BNE   @@L39
         L     2,8(11)
         A     2,=F'9'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         MVC   96(4,13),=A(@@LC11)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         B     @@L34
@@L39    EQU   *
         L     12,0(,10)
         L     2,8(11)
         A     2,=F'9'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         MVC   96(4,13),=A(@@LC12)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
@@L34    EQU   *
         L     12,0(,10)
         L     2,8(11)
         MVC   20(4,2),112(13)
         L     2,8(11)
         MVC   24(4,2),116(13)
         L     2,8(11)
         MVC   28(4,2),=F'0'
         L     2,4(11)
         MVC   0(4,2),104(13)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   136(4,13),=F'0'
@@L17    EQU   *
         L     12,0(,10)
         L     15,136(13)
* Function mvsrs_driver_open epilogue
         PDPEPIL
* Function mvsrs_driver_open literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_open page table
         DS    0F
@@PGT3   EQU   *
         DC    A(@@PG3)
@@LC13   EQU   *
         DC    C'MVS QSAM CLOSE failed'
         DC    X'0'
         DS    0F
* X-func mvsrs_driver_close prologue
MVSRS@DR PDPPRLG CINDEX=4,FRAME=120,BASER=12,ENTRY=YES
         B     @@FEN4
         LTORG
@@FEN4   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG4    EQU   *
         LR    11,1
         L     10,=A(@@PGT4)
* Function mvsrs_driver_close code
         MVC   104(4,13),0(11)
         L     2,104(13)
         LTR   2,2
         BNE   @@L42
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   112(4,13),=F'0'
         B     @@L41
@@L42    EQU   *
         L     12,0(,10)
         L     2,104(13)
         MVC   88(4,13),0(2)
         LA    1,88(,13)
         L     15,=V(RQCLOSE)
         BALR  14,15
         LR    2,15
         ST    2,108(13)
         MVC   88(4,13),104(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   88(4,13),108(13)
         MVC   92(4,13),8(11)
         MVC   96(4,13),12(11)
         MVC   100(4,13),=A(@@LC13)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
@@L41    EQU   *
         L     12,0(,10)
         L     15,112(13)
* Function mvsrs_driver_close epilogue
         PDPEPIL
* Function mvsrs_driver_close literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_close page table
         DS    0F
@@PGT4   EQU   *
         DC    A(@@PG4)
@@LC14   EQU   *
         DC    C'Invalid MVS QSAM READ request'
         DC    X'0'
@@LC15   EQU   *
         DC    C'MVS QSAM GET failed'
         DC    X'0'
         DS    0F
* X-func mvsrs_driver_read prologue
MVSRS@DR PDPPRLG CINDEX=5,FRAME=120,BASER=12,ENTRY=YES
         B     @@FEN5
         LTORG
@@FEN5   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG5    EQU   *
         LR    11,1
         L     10,=A(@@PGT5)
* Function mvsrs_driver_read code
         MVC   104(4,13),0(11)
         L     2,12(11)
         LTR   2,2
         BE    @@L44
         L     2,12(11)
         MVC   0(4,2),=F'0'
@@L44    EQU   *
         L     12,0(,10)
         L     2,104(13)
         LTR   2,2
         BE    @@L46
         L     2,104(13)
         L     2,4(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L46
         L     2,4(11)
         LTR   2,2
         BE    @@L46
         L     2,12(11)
         LTR   2,2
         BNE   @@L45
@@L46    EQU   *
         L     12,0(,10)
         MVC   88(4,13),16(11)
         MVC   92(4,13),20(11)
         MVC   96(4,13),=A(@@LC14)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   112(4,13),=F'4'
         B     @@L43
@@L45    EQU   *
         L     12,0(,10)
         L     2,104(13)
         MVC   88(4,13),0(2)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         MVC   100(4,13),12(11)
         LA    1,88(,13)
         L     15,=V(RQREAD)
         BALR  14,15
         LR    2,15
         ST    2,108(13)
         MVC   88(4,13),108(13)
         MVC   92(4,13),16(11)
         MVC   96(4,13),20(11)
         MVC   100(4,13),=A(@@LC15)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
@@L43    EQU   *
         L     12,0(,10)
         L     15,112(13)
* Function mvsrs_driver_read epilogue
         PDPEPIL
* Function mvsrs_driver_read literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_read page table
         DS    0F
@@PGT5   EQU   *
         DC    A(@@PG5)
@@LC16   EQU   *
         DC    C'Invalid MVS QSAM WRITE request'
         DC    X'0'
@@LC17   EQU   *
         DC    C'MVS QSAM PUT failed'
         DC    X'0'
         DS    0F
* X-func mvsrs_driver_write prologue
MVSRS@DR PDPPRLG CINDEX=6,FRAME=120,BASER=12,ENTRY=YES
         B     @@FEN6
         LTORG
@@FEN6   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG6    EQU   *
         LR    11,1
         L     10,=A(@@PGT6)
* Function mvsrs_driver_write code
         MVC   104(4,13),0(11)
         L     2,104(13)
         LTR   2,2
         BE    @@L49
         L     2,104(13)
         L     2,4(2)
         LA    3,2(0,0)
         CLR   2,3
         BE    @@L50
         L     2,104(13)
         L     2,4(2)
         LA    3,3(0,0)
         CLR   2,3
         BNE   @@L49
@@L50    EQU   *
         L     12,0(,10)
         L     2,4(11)
         LTR   2,2
         BNE   @@L48
         L     2,8(11)
         LTR   2,2
         BNE   @@L49
         B     @@L48
@@L49    EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC16)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   112(4,13),=F'4'
         B     @@L47
@@L48    EQU   *
         L     12,0(,10)
         L     2,104(13)
         MVC   88(4,13),0(2)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         LA    1,88(,13)
         L     15,=V(RQWRITE)
         BALR  14,15
         LR    2,15
         ST    2,108(13)
         MVC   88(4,13),108(13)
         MVC   92(4,13),12(11)
         MVC   96(4,13),16(11)
         MVC   100(4,13),=A(@@LC17)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
@@L47    EQU   *
         L     12,0(,10)
         L     15,112(13)
* Function mvsrs_driver_write epilogue
         PDPEPIL
* Function mvsrs_driver_write literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_write page table
         DS    0F
@@PGT6   EQU   *
         DC    A(@@PG6)
@@LC18   EQU   *
         DC    C'Invalid MVS QSAM rewind request'
         DC    X'0'
@@LC19   EQU   *
         DC    C'MVS QSAM rewind failed'
         DC    X'0'
         DS    0F
* X-func mvsrs_driver_rewind prologue
MVSRS@DR PDPPRLG CINDEX=7,FRAME=120,BASER=12,ENTRY=YES
         B     @@FEN7
         LTORG
@@FEN7   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG7    EQU   *
         LR    11,1
         L     10,=A(@@PGT7)
* Function mvsrs_driver_rewind code
         MVC   104(4,13),0(11)
         L     2,104(13)
         LTR   2,2
         BE    @@L53
         L     2,104(13)
         L     2,4(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L53
         B     @@L52
@@L53    EQU   *
         L     12,0(,10)
         MVC   88(4,13),4(11)
         MVC   92(4,13),8(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   112(4,13),=F'4'
         B     @@L51
@@L52    EQU   *
         L     12,0(,10)
         L     2,104(13)
         MVC   88(4,13),0(2)
         LA    1,88(,13)
         L     15,=V(RQREWIND)
         BALR  14,15
         LR    2,15
         ST    2,108(13)
         MVC   88(4,13),108(13)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         MVC   100(4,13),=A(@@LC19)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
@@L51    EQU   *
         L     12,0(,10)
         L     15,112(13)
* Function mvsrs_driver_rewind epilogue
         PDPEPIL
* Function mvsrs_driver_rewind literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_rewind page table
         DS    0F
@@PGT7   EQU   *
         DC    A(@@PG7)
         DS    0F
* X-func mvsrs_driver_record_count prologue
MVSRS@DR PDPPRLG CINDEX=8,FRAME=104,BASER=12,ENTRY=YES
         B     @@FEN8
         LTORG
@@FEN8   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG8    EQU   *
         LR    11,1
         L     10,=A(@@PGT8)
* Function mvsrs_driver_record_count code
         L     2,4(11)
         LTR   2,2
         BE    @@L55
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L55    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         LA    2,2(0,0)
         LR    15,2
* Function mvsrs_driver_record_count epilogue
         PDPEPIL
* Function mvsrs_driver_record_count literal pool
         DS    0F
         LTORG
* Function mvsrs_driver_record_count page table
         DS    0F
@@PGT8   EQU   *
         DC    A(@@PG8)
         END
