         COPY  PDPTOP
         CSECT
* Program text area
         DS    0F
* Function prefix,F1 prologue
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
* Function prefix code
         L     2,0(11)
         LTR   2,2
         BE    @@L3
         L     2,8(11)
         LTR   2,2
         BNE   @@L2
@@L3     EQU   *
         L     12,0(,10)
         MVC   92(4,13),=F'0'
         B     @@L1
@@L2     EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'0'
@@L4     EQU   *
         L     2,8(11)
         A     2,88(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L5
         L     2,88(13)
         CL    2,4(11)
         BNL   @@L7
         L     2,0(11)
         A     2,88(13)
         L     3,8(11)
         A     3,88(13)
         IC    2,0(2)
         CLM   2,1,0(3)
         BNE   @@L7
         B     @@L6
@@L7     EQU   *
         L     12,0(,10)
         MVC   92(4,13),=F'0'
         B     @@L1
@@L6     EQU   *
         L     12,0(,10)
         L     2,88(13)
         A     2,=F'1'
         ST    2,88(13)
         B     @@L4
@@L5     EQU   *
         L     12,0(,10)
         MVC   92(4,13),=F'1'
@@L1     EQU   *
         L     12,0(,10)
         L     15,92(13)
* Function prefix epilogue
         PDPEPIL
* Function prefix literal pool
         DS    0F
         LTORG
* Function prefix page table
         DS    0F
@@PGT0   EQU   *
         DC    A(@@PG0)
@@LC0    EQU   *
         DC    C'DD:RSIN'
         DC    X'0'
@@LC1    EQU   *
         DC    C'ALPHA'
         DC    X'0'
@@LC2    EQU   *
         DC    C'DD:RSOUT'
         DC    X'0'
@@LC3    EQU   *
         DC    C'ONE'
         DC    X'0'
@@LC4    EQU   *
         DC    C'TWO'
         DC    X'0'
         DS    0F
         DC    C'GCCMVS!!'
         EXTRN @@CRT0
         ENTRY @@MAIN
@@MAIN   DS    0H
         BALR  15,0
         USING *,15
         L     15,=V(@@CRT0)
         BR    15
         DROP  15
         LTORG
* X-func main prologue
MAIN     PDPPRLG CINDEX=1,FRAME=296,BASER=12,ENTRY=YES
         B     @@FEN1
         LTORG
@@FEN1   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG1    EQU   *
         LR    11,1
         L     10,=A(@@PGT1)
* Function main code
         MVC   112(4,13),=F'0'
         MVC   116(4,13),=F'0'
         MVC   120(4,13),=F'0'
         MVC   124(4,13),=F'0'
         MVC   88(4,13),=A(@@LC0)
         MVC   92(4,13),=F'1'
         LA    2,112(,13)
         ST    2,96(13)
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@OPEN)
         BALR  14,15
         LR    2,15
         ST    2,288(13)
         L     2,288(13)
         LTR   2,2
         BE    @@L9
         MVC   292(4,13),=F'20'
         B     @@L8
@@L9     EQU   *
         L     12,0(,10)
         MVC   88(4,13),112(13)
         LA    2,120(,13)
         ST    2,92(13)
         LA    2,124(,13)
         ST    2,96(13)
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@READ@)
         BALR  14,15
         LR    2,15
         ST    2,288(13)
         L     2,288(13)
         LTR   2,2
         BE    @@L10
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'21'
         B     @@L8
@@L10    EQU   *
         L     12,0(,10)
         MVC   88(4,13),120(13)
         MVC   92(4,13),124(13)
         MVC   96(4,13),=A(@@LC1)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L11
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(RS@FREE@)
         BALR  14,15
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'22'
         B     @@L8
@@L11    EQU   *
         L     12,0(,10)
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(RS@FREE@)
         BALR  14,15
         MVC   120(4,13),=F'0'
         MVC   88(4,13),112(13)
         MVC   92(4,13),=F'1'
         LA    2,128(,13)
         ST    2,96(13)
         MVC   100(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@POSIT)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L12
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'23'
         B     @@L8
@@L12    EQU   *
         L     12,0(,10)
         MVC   88(4,13),112(13)
         LA    2,120(,13)
         ST    2,92(13)
         LA    2,124(,13)
         ST    2,96(13)
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@READ@)
         BALR  14,15
         LR    2,15
         ST    2,288(13)
         L     2,288(13)
         LTR   2,2
         BNE   @@L14
         MVC   88(4,13),120(13)
         MVC   92(4,13),124(13)
         MVC   96(4,13),=A(@@LC1)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L13
@@L14    EQU   *
         L     12,0(,10)
         L     2,120(13)
         LTR   2,2
         BE    @@L15
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(RS@FREE@)
         BALR  14,15
@@L15    EQU   *
         L     12,0(,10)
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'24'
         B     @@L8
@@L13    EQU   *
         L     12,0(,10)
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(RS@FREE@)
         BALR  14,15
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   88(4,13),=A(@@LC2)
         MVC   92(4,13),=F'2'
         LA    2,116(,13)
         ST    2,96(13)
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@OPEN)
         BALR  14,15
         LR    2,15
         ST    2,288(13)
         L     2,288(13)
         LTR   2,2
         BE    @@L16
         MVC   292(4,13),=F'30'
         B     @@L8
@@L16    EQU   *
         L     12,0(,10)
         MVC   88(4,13),116(13)
         MVC   92(4,13),=A(@@LC3)
         MVC   96(4,13),=F'3'
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@WRITE)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L17
         MVC   88(4,13),116(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'31'
         B     @@L8
@@L17    EQU   *
         L     12,0(,10)
         MVC   88(4,13),116(13)
         MVC   92(4,13),=A(@@LC4)
         MVC   96(4,13),=F'3'
         LA    2,128(,13)
         ST    2,100(13)
         MVC   104(4,13),=F'160'
         LA    1,88(,13)
         L     15,=V(RS@WRITE)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L18
         MVC   88(4,13),116(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'32'
         B     @@L8
@@L18    EQU   *
         L     12,0(,10)
         MVC   88(4,13),116(13)
         LA    1,88(,13)
         L     15,=V(RS@CLOSE)
         BALR  14,15
         MVC   292(4,13),=F'0'
@@L8     EQU   *
         L     12,0(,10)
         L     15,292(13)
* Function main epilogue
         PDPEPIL
* Function main literal pool
         DS    0F
         LTORG
* Function main page table
         DS    0F
@@PGT1   EQU   *
         DC    A(@@PG1)
         END   @@MAIN
