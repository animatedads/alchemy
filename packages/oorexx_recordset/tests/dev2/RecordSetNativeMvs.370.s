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
* Function ascii_upper,F2 prologue
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
* Function ascii_upper code
         L     2,0(11)
         LA    3,128(0,0)
         CR    2,3
         BNH   @@L8
         L     2,0(11)
         LA    3,169(0,0)
         CR    2,3
         BH    @@L8
         L     2,0(11)
         A     2,=F'64'
         ST    2,88(13)
         B     @@L7
@@L8     EQU   *
         L     12,0(,10)
         L     2,0(11)
         ST    2,88(13)
@@L7     EQU   *
         L     12,0(,10)
         L     15,88(13)
* Function ascii_upper epilogue
         PDPEPIL
* Function ascii_upper literal pool
         DS    0F
         LTORG
* Function ascii_upper page table
         DS    0F
@@PGT1   EQU   *
         DC    A(@@PG1)
         DS    0F
* Function rs_streq_ci,F3 prologue
@@F3     PDPPRLG CINDEX=2,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN2
         LTORG
@@FEN2   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG2    EQU   *
         LR    11,1
         L     10,=A(@@PGT2)
* Function rs_streq_ci code
         L     2,0(11)
         LTR   2,2
         BE    @@L11
         L     2,4(11)
         LTR   2,2
         BNE   @@L12
@@L11    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'0'
         B     @@L9
@@L12    EQU   *
         L     12,0(,10)
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L13
         L     2,4(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L13
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    3,15
         L     2,4(11)
         SLR   4,4
         IC    4,0(2)
         LR    2,4
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         CLR   3,2
         BE    @@L14
         MVC   96(4,13),=F'0'
         B     @@L9
@@L14    EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'1'
         ST    2,0(11)
         L     2,4(11)
         A     2,=F'1'
         ST    2,4(11)
         B     @@L12
@@L13    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         L     2,0(11)
         L     3,4(11)
         IC    2,0(2)
         CLM   2,1,0(3)
         BNE   @@L15
         MVC   100(4,13),=F'1'
@@L15    EQU   *
         L     12,0(,10)
         MVC   96(4,13),100(13)
@@L9     EQU   *
         L     12,0(,10)
         L     15,96(13)
* Function rs_streq_ci epilogue
         PDPEPIL
* Function rs_streq_ci literal pool
         DS    0F
         LTORG
* Function rs_streq_ci page table
         DS    0F
@@PGT2   EQU   *
         DC    A(@@PG2)
         DS    0F
* Function copy_upper,F4 prologue
@@F4     PDPPRLG CINDEX=3,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN3
         LTORG
@@FEN3   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG3    EQU   *
         LR    11,1
         L     10,=A(@@PGT3)
* Function copy_upper code
         L     2,0(11)
         LTR   2,2
         BE    @@L18
         L     2,4(11)
         LTR   2,2
         BE    @@L18
         L     2,8(11)
         LTR   2,2
         BE    @@L18
         L     2,12(11)
         A     2,=F'1'
         CL    2,4(11)
         BH    @@L18
         B     @@L17
@@L18    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L16
@@L17    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'0'
@@L19    EQU   *
         L     2,96(13)
         CL    2,12(11)
         BNL   @@L20
         L     3,0(11)
         A     3,96(13)
         L     2,8(11)
         A     2,96(13)
         SLR   4,4
         IC    4,0(2)
         LR    2,4
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         STC   2,0(3)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L19
@@L20    EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,12(11)
         MVI   0(2),0
         MVC   100(4,13),=F'1'
@@L16    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function copy_upper epilogue
         PDPEPIL
* Function copy_upper literal pool
         DS    0F
         LTORG
* Function copy_upper page table
         DS    0F
@@PGT3   EQU   *
         DC    A(@@PG3)
         DS    0F
* Function is_dd_first,F5 prologue
@@F5     PDPPRLG CINDEX=4,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN4
         LTORG
@@FEN4   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG4    EQU   *
         LR    11,1
         L     10,=A(@@PGT4)
* Function is_dd_first code
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         ST    2,0(11)
         MVC   96(4,13),=F'0'
         L     2,0(11)
         LA    3,192(0,0)
         CR    2,3
         BNH   @@L25
         L     2,0(11)
         LA    3,233(0,0)
         CR    2,3
         BNH   @@L24
@@L25    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,124(0,0)
         CLR   2,3
         BE    @@L24
         L     2,0(11)
         LA    3,123(0,0)
         CLR   2,3
         BE    @@L24
         L     2,0(11)
         LA    3,91(0,0)
         CLR   2,3
         BE    @@L24
         B     @@L23
@@L24    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L23    EQU   *
         L     12,0(,10)
         L     2,96(13)
         LR    15,2
* Function is_dd_first epilogue
         PDPEPIL
* Function is_dd_first literal pool
         DS    0F
         LTORG
* Function is_dd_first page table
         DS    0F
@@PGT4   EQU   *
         DC    A(@@PG4)
         DS    0F
* Function is_dd_rest,F6 prologue
@@F6     PDPPRLG CINDEX=5,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN5
         LTORG
@@FEN5   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG5    EQU   *
         LR    11,1
         L     10,=A(@@PGT5)
* Function is_dd_rest code
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         ST    2,0(11)
         MVC   96(4,13),=F'0'
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L28
         L     2,0(11)
         LA    3,239(0,0)
         CR    2,3
         BNH   @@L27
         L     2,0(11)
         LA    3,249(0,0)
         CR    2,3
         BNH   @@L28
         B     @@L27
@@L28    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L27    EQU   *
         L     12,0(,10)
         L     2,96(13)
         LR    15,2
* Function is_dd_rest epilogue
         PDPEPIL
* Function is_dd_rest literal pool
         DS    0F
         LTORG
* Function is_dd_rest page table
         DS    0F
@@PGT5   EQU   *
         DC    A(@@PG5)
         DS    0F
* Function valid_dd,F7 prologue
@@F7     PDPPRLG CINDEX=6,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN6
         LTORG
@@FEN6   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG6    EQU   *
         LR    11,1
         L     10,=A(@@PGT6)
* Function valid_dd code
         L     2,0(11)
         LTR   2,2
         BE    @@L31
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L31
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L30
@@L31    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L29
@@L30    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L32    EQU   *
         L     2,0(11)
         A     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L33
         L     2,96(13)
         LA    3,7(0,0)
         CLR   2,3
         BH    @@L36
         L     2,0(11)
         A     2,96(13)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F6)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L34
@@L36    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L29
@@L34    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L32
@@L33    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'1'
@@L29    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function valid_dd epilogue
         PDPEPIL
* Function valid_dd literal pool
         DS    0F
         LTORG
* Function valid_dd page table
         DS    0F
@@PGT6   EQU   *
         DC    A(@@PG6)
         DS    0F
* Function valid_ds_qualifier,F8 prologue
@@F8     PDPPRLG CINDEX=7,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN7
         LTORG
@@FEN7   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG7    EQU   *
         LR    11,1
         L     10,=A(@@PGT7)
* Function valid_ds_qualifier code
         L     2,4(11)
         LTR   2,2
         BE    @@L39
         L     2,4(11)
         LA    3,8(0,0)
         CLR   2,3
         BH    @@L39
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L38
@@L39    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L37
@@L38    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L40    EQU   *
         L     2,96(13)
         CL    2,4(11)
         BNL   @@L41
         L     2,0(11)
         A     2,96(13)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F6)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L42
         L     2,0(11)
         A     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'60'
         BE    @@L42
         MVC   100(4,13),=F'0'
         B     @@L37
@@L42    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L40
@@L41    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'1'
@@L37    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function valid_ds_qualifier epilogue
         PDPEPIL
* Function valid_ds_qualifier literal pool
         DS    0F
         LTORG
* Function valid_ds_qualifier page table
         DS    0F
@@PGT7   EQU   *
         DC    A(@@PG7)
         DS    0F
* Function valid_dataset,F9 prologue
@@F9     PDPPRLG CINDEX=8,FRAME=112,BASER=12,ENTRY=NO
         B     @@FEN8
         LTORG
@@FEN8   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG8    EQU   *
         LR    11,1
         L     10,=A(@@PGT8)
* Function valid_dataset code
         L     2,0(11)
         LTR   2,2
         BE    @@L46
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L45
@@L46    EQU   *
         L     12,0(,10)
         MVC   104(4,13),=F'0'
         B     @@L44
@@L45    EQU   *
         L     12,0(,10)
         MVC   96(4,13),0(11)
         MVC   100(4,13),96(13)
@@L47    EQU   *
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'4B'
         BE    @@L50
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L49
@@L50    EQU   *
         L     12,0(,10)
         MVC   88(4,13),100(13)
         L     2,96(13)
         S     2,100(13)
         ST    2,92(13)
         LA    1,88(,13)
         L     15,=A(@@F8)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L51
         MVC   104(4,13),=F'0'
         B     @@L44
@@L51    EQU   *
         L     12,0(,10)
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L52
         B     @@L48
@@L52    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,100(13)
@@L49    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L47
@@L48    EQU   *
         L     12,0(,10)
         MVC   104(4,13),=F'1'
@@L44    EQU   *
         L     12,0(,10)
         L     15,104(13)
* Function valid_dataset epilogue
         PDPEPIL
* Function valid_dataset literal pool
         DS    0F
         LTORG
* Function valid_dataset page table
         DS    0F
@@PGT8   EQU   *
         DC    A(@@PG8)
@@LC1    EQU   *
         DC    C'RecordSet resource is empty'
         DC    X'0'
@@LC2    EQU   *
         DC    C'RecordSet resource name is too long'
         DC    X'0'
@@LC3    EQU   *
         DC    C'Invalid MVS DD name'
         DC    X'0'
@@LC4    EQU   *
         DC    C'Empty MVS dataset name'
         DC    X'0'
@@LC5    EQU   *
         DC    C'Invalid dataset member syntax'
         DC    X'0'
@@LC6    EQU   *
         DC    C'Dataset or member name is too long'
         DC    X'0'
@@LC7    EQU   *
         DC    C'Invalid MVS dataset or member name'
         DC    X'0'
@@LC8    EQU   *
         DC    C'Invalid MVS dataset name'
         DC    X'0'
         DS    0F
* Function parse_resource,F10 prologue
@@F10    PDPPRLG CINDEX=9,FRAME=136,BASER=12,ENTRY=NO
         B     @@FEN9
         LTORG
@@FEN9   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG9    EQU   *
         LR    11,1
         L     10,=A(@@PGT9)
* Function parse_resource code
         L     2,0(11)
         LTR   2,2
         BE    @@L55
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L54
@@L55    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC1)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L54    EQU   *
         L     12,0(,10)
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=V(STRLEN)
         BALR  14,15
         LR    2,15
         ST    2,120(13)
         L     2,120(13)
         LA    3,143(0,0)
         CLR   2,3
         BNH   @@L56
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC2)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L56    EQU   *
         L     12,0(,10)
         L     2,4(11)
         A     2,=F'28'
         ST    2,88(13)
         MVC   92(4,13),0(11)
         LA    1,88(,13)
         L     15,=V(STRCPY)
         BALR  14,15
         L     2,120(13)
         LA    3,2(0,0)
         CLR   2,3
         BNH   @@L57
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         LA    3,196(0,0)
         CLR   2,3
         BNE   @@L57
         LA    2,1(0,0)
         A     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         LA    3,196(0,0)
         CLR   2,3
         BNE   @@L57
         LA    2,2(0,0)
         A     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'7A'
         BNE   @@L57
         L     2,4(11)
         A     2,=F'172'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         L     2,0(11)
         A     2,=F'3'
         ST    2,96(13)
         L     2,120(13)
         A     2,=F'-3'
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L59
         L     2,4(11)
         A     2,=F'172'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F7)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L58
@@L59    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC3)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L58    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'1'
         MVC   128(4,13),=F'0'
         B     @@L53
@@L57    EQU   *
         L     12,0(,10)
         MVC   104(4,13),0(11)
         L     2,0(11)
         A     2,120(13)
         ST    2,108(13)
         L     2,120(13)
         LA    3,1(0,0)
         CLR   2,3
         BNH   @@L60
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'7D'
         BNE   @@L60
         L     3,=F'-1'
         L     2,0(11)
         A     2,120(13)
         AR    2,3
         IC    2,0(2)
         CLM   2,1,=XL1'7D'
         BNE   @@L60
         L     2,104(13)
         A     2,=F'1'
         ST    2,104(13)
         L     2,108(13)
         BCTR  2,0
         ST    2,108(13)
@@L60    EQU   *
         L     12,0(,10)
         L     2,104(13)
         CL    2,108(13)
         BNE   @@L61
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC4)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L61    EQU   *
         L     12,0(,10)
         MVC   112(4,13),=F'0'
         MVC   116(4,13),=F'0'
         MVC   124(4,13),104(13)
@@L62    EQU   *
         L     2,124(13)
         CL    2,108(13)
         BNL   @@L63
         L     2,124(13)
         IC    2,0(2)
         CLM   2,1,=XL1'4D'
         BNE   @@L65
         L     2,112(13)
         LTR   2,2
         BE    @@L66
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC5)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L66    EQU   *
         L     12,0(,10)
         MVC   112(4,13),124(13)
         B     @@L64
@@L65    EQU   *
         L     12,0(,10)
         L     2,124(13)
         IC    2,0(2)
         CLM   2,1,=XL1'5D'
         BNE   @@L64
         MVC   116(4,13),124(13)
@@L64    EQU   *
         L     12,0(,10)
         L     2,124(13)
         A     2,=F'1'
         ST    2,124(13)
         B     @@L62
@@L63    EQU   *
         L     12,0(,10)
         L     2,112(13)
         LTR   2,2
         BE    @@L69
         L     2,108(13)
         BCTR  2,0
         CL    2,116(13)
         BNE   @@L71
         L     2,112(13)
         A     2,=F'1'
         CL    2,116(13)
         BNL   @@L71
         B     @@L70
@@L71    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC5)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L70    EQU   *
         L     12,0(,10)
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         MVC   92(4,13),=F'129'
         MVC   96(4,13),104(13)
         L     2,112(13)
         S     2,104(13)
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L73
         L     2,4(11)
         A     2,=F'310'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         L     2,112(13)
         A     2,=F'1'
         ST    2,96(13)
         L     2,116(13)
         S     2,112(13)
         BCTR  2,0
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L72
@@L73    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC6)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L72    EQU   *
         L     12,0(,10)
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F9)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L75
         L     2,4(11)
         A     2,=F'310'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F7)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L74
@@L75    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC7)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L74    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'3'
         B     @@L76
@@L69    EQU   *
         L     12,0(,10)
         L     2,116(13)
         LTR   2,2
         BNE   @@L78
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         MVC   92(4,13),=F'129'
         MVC   96(4,13),104(13)
         L     2,108(13)
         S     2,104(13)
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L78
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F9)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L77
@@L78    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC8)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L53
@@L77    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'2'
@@L76    EQU   *
         L     12,0(,10)
         MVC   128(4,13),=F'0'
@@L53    EQU   *
         L     12,0(,10)
         L     15,128(13)
* Function parse_resource epilogue
         PDPEPIL
* Function parse_resource literal pool
         DS    0F
         LTORG
* Function parse_resource page table
         DS    0F
@@PGT9   EQU   *
         DC    A(@@PG9)
@@LC9    EQU   *
         DC    C'READ'
         DC    X'0'
@@LC10   EQU   *
         DC    C'R'
         DC    X'0'
@@LC11   EQU   *
         DC    C'WRITE'
         DC    X'0'
@@LC12   EQU   *
         DC    C'W'
         DC    X'0'
@@LC13   EQU   *
         DC    C'APPEND'
         DC    X'0'
@@LC14   EQU   *
         DC    C'A'
         DC    X'0'
         DS    0F
* X-func rs_mode_from_text prologue
RS@MODE@ PDPPRLG CINDEX=10,FRAME=104,BASER=12,ENTRY=YES
         B     @@FEN10
         LTORG
@@FEN10  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG10   EQU   *
         LR    11,1
         L     10,=A(@@PGT10)
* Function rs_mode_from_text code
         L     2,4(11)
         LTR   2,2
         BNE   @@L80
         MVC   96(4,13),=F'3'
         B     @@L79
@@L80    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L82
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L82
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC9)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L82
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC10)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L82
         B     @@L81
@@L82    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'1'
         MVC   96(4,13),=F'0'
         B     @@L79
@@L81    EQU   *
         L     12,0(,10)
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC11)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L84
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC12)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L84
         B     @@L83
@@L84    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'2'
         MVC   96(4,13),=F'0'
         B     @@L79
@@L83    EQU   *
         L     12,0(,10)
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC13)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L86
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC14)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L86
         B     @@L85
@@L86    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'3'
         MVC   96(4,13),=F'0'
         B     @@L79
@@L85    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'3'
@@L79    EQU   *
         L     12,0(,10)
         L     15,96(13)
* Function rs_mode_from_text epilogue
         PDPEPIL
* Function rs_mode_from_text literal pool
         DS    0F
         LTORG
* Function rs_mode_from_text page table
         DS    0F
@@PGT10  EQU   *
         DC    A(@@PG10)
@@LC15   EQU   *
         DC    C'RecordSet open requires a handle result'
         DC    X'0'
@@LC16   EQU   *
         DC    C'Invalid RecordSet mode'
         DC    X'0'
@@LC17   EQU   *
         DC    C'RecordSet handle allocation failed'
         DC    X'0'
         DS    0F
* X-func rs_open prologue
RS@OPEN  PDPPRLG CINDEX=11,FRAME=200,BASER=12,ENTRY=YES
         B     @@FEN11
         LTORG
@@FEN11  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG11   EQU   *
         LR    11,1
         L     10,=A(@@PGT11)
* Function rs_open code
         L     2,8(11)
         LTR   2,2
         BNE   @@L88
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC15)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L87
@@L88    EQU   *
         L     12,0(,10)
         L     2,8(11)
         MVC   0(4,2),=F'0'
         L     2,4(11)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L89
         L     2,4(11)
         LA    3,2(0,0)
         CLR   2,3
         BE    @@L89
         L     2,4(11)
         LA    3,3(0,0)
         CLR   2,3
         BE    @@L89
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC16)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L87
@@L89    EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'1'
         MVC   92(4,13),=F'348'
         LA    1,88(,13)
         L     15,=V(CALLOC)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
         L     2,112(13)
         LTR   2,2
         BNE   @@L90
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC17)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L87
@@L90    EQU   *
         L     12,0(,10)
         L     2,112(13)
         MVC   12(4,2),4(11)
         L     2,112(13)
         MVC   20(4,2),=F'1'
         MVC   88(4,13),0(11)
         MVC   92(4,13),112(13)
         MVC   96(4,13),12(11)
         MVC   100(4,13),16(11)
         LA    1,88(,13)
         L     15,=A(@@F10)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L91
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L87
@@L91    EQU   *
         L     12,0(,10)
         LA    2,120(,13)
         ST    2,88(13)
         MVC   92(4,13),=F'0'
         MVC   96(4,13),=F'20'
         LA    1,88(,13)
         L     15,=V(MEMSET)
         BALR  14,15
         LA    2,144(,13)
         ST    2,88(13)
         MVC   92(4,13),=F'0'
         MVC   96(4,13),=F'32'
         LA    1,88(,13)
         L     15,=V(MEMSET)
         BALR  14,15
         L     2,112(13)
         MVC   120(4,13),16(2)
         MVC   124(4,13),4(11)
         L     2,112(13)
         IC    2,172(2)
         CLM   2,1,=XL1'00'
         BE    @@L92
         L     2,112(13)
         A     2,=F'172'
         ST    2,184(13)
         B     @@L93
@@L92    EQU   *
         L     12,0(,10)
         MVC   184(4,13),=F'0'
@@L93    EQU   *
         L     12,0(,10)
         MVC   128(4,13),184(13)
         L     2,112(13)
         IC    2,181(2)
         CLM   2,1,=XL1'00'
         BE    @@L94
         L     3,112(13)
         A     3,=F'181'
         ST    3,188(13)
         B     @@L95
@@L94    EQU   *
         L     12,0(,10)
         MVC   188(4,13),=F'0'
@@L95    EQU   *
         L     12,0(,10)
         MVC   132(4,13),188(13)
         L     2,112(13)
         IC    2,310(2)
         CLM   2,1,=XL1'00'
         BE    @@L96
         L     2,112(13)
         A     2,=F'310'
         ST    2,192(13)
         B     @@L97
@@L96    EQU   *
         L     12,0(,10)
         MVC   192(4,13),=F'0'
@@L97    EQU   *
         L     12,0(,10)
         MVC   136(4,13),192(13)
         LA    2,120(,13)
         ST    2,88(13)
         L     2,112(13)
         A     2,=F'24'
         ST    2,92(13)
         LA    2,144(,13)
         ST    2,96(13)
         MVC   100(4,13),12(11)
         MVC   104(4,13),16(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,176(13)
         L     2,176(13)
         LTR   2,2
         BE    @@L98
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L87
@@L98    EQU   *
         L     12,0(,10)
         L     2,112(13)
         MVC   8(4,2),172(13)
         LA    2,144(,13)
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=V(STRLEN)
         BALR  14,15
         LR    2,15
         LR    3,2
         L     2,112(13)
         A     2,=F'319'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         LA    2,144(,13)
         ST    2,96(13)
         ST    3,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LA    2,144(,13)
         A     2,=F'9'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=V(STRLEN)
         BALR  14,15
         LR    2,15
         LR    3,2
         L     2,112(13)
         A     2,=F'328'
         ST    2,88(13)
         MVC   92(4,13),=F'9'
         LA    2,144(,13)
         A     2,=F'9'
         ST    2,96(13)
         ST    3,100(13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         L     2,112(13)
         MVC   340(4,2),164(13)
         L     2,112(13)
         MVC   344(4,2),168(13)
         L     2,112(13)
         MVC   0(4,2),=F'1'
         L     2,8(11)
         MVC   0(4,2),112(13)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC0)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'0'
@@L87    EQU   *
         L     12,0(,10)
         L     15,180(13)
* Function rs_open epilogue
         PDPEPIL
* Function rs_open literal pool
         DS    0F
         LTORG
* Function rs_open page table
         DS    0F
@@PGT11  EQU   *
         DC    A(@@PG11)
         DS    0F
* X-func rs_close prologue
RS@CLOSE PDPPRLG CINDEX=12,FRAME=112,BASER=12,ENTRY=YES
         B     @@FEN12
         LTORG
@@FEN12  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG12   EQU   *
         LR    11,1
         L     10,=A(@@PGT12)
* Function rs_close code
         L     2,0(11)
         LTR   2,2
         BNE   @@L100
         B     @@L99
@@L100   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L101
         L     2,0(11)
         L     2,24(2)
         LTR   2,2
         BE    @@L101
         L     2,0(11)
         MVC   88(4,13),24(2)
         L     2,0(11)
         MVC   92(4,13),8(2)
         LA    2,104(,13)
         ST    2,96(13)
         MVC   100(4,13),=F'2'
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
@@L101   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   0(4,2),=F'0'
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
@@L99    EQU   *
         L     12,0(,10)
* Function rs_close epilogue
         PDPEPIL
* Function rs_close literal pool
         DS    0F
         LTORG
* Function rs_close page table
         DS    0F
@@PGT12  EQU   *
         DC    A(@@PG12)
         DS    0F
* X-func rs_is_open prologue
RS@IS@OP PDPPRLG CINDEX=13,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN13
         LTORG
@@FEN13  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG13   EQU   *
         LR    11,1
         L     10,=A(@@PGT13)
* Function rs_is_open code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L103
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L103
         MVC   88(4,13),=F'1'
@@L103   EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function rs_is_open epilogue
         PDPEPIL
* Function rs_is_open literal pool
         DS    0F
         LTORG
* Function rs_is_open page table
         DS    0F
@@PGT13  EQU   *
         DC    A(@@PG13)
@@LC18   EQU   *
         DC    C'RecordSet is closed'
         DC    X'0'
@@LC19   EQU   *
         DC    C'RecordSet is not open for reading'
         DC    X'0'
@@LC20   EQU   *
         DC    C'RecordSet record allocation failed'
         DC    X'0'
@@LC21   EQU   *
         DC    C'MVS RecordSet driver returned an oversized logic'
         DC    C'al record'
         DC    X'0'
         DS    0F
* X-func rs_read_record prologue
RS@READ@ PDPPRLG CINDEX=14,FRAME=144,BASER=12,ENTRY=YES
         B     @@FEN14
         LTORG
@@FEN14  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG14   EQU   *
         LR    11,1
         L     10,=A(@@PGT14)
* Function rs_read_record code
         L     2,4(11)
         LTR   2,2
         BE    @@L105
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L105   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L106
         L     2,8(11)
         MVC   0(4,2),=F'0'
@@L106   EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L108
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L107
@@L108   EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L104
@@L107   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L109
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC19)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L104
@@L109   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   132(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L110
         MVC   132(4,13),=F'32760'
@@L110   EQU   *
         L     12,0(,10)
         MVC   116(4,13),132(13)
         MVC   136(4,13),116(13)
         L     2,116(13)
         LTR   2,2
         BNE   @@L111
         MVC   136(4,13),=F'1'
@@L111   EQU   *
         L     12,0(,10)
         MVC   88(4,13),136(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
         L     2,112(13)
         LTR   2,2
         BNE   @@L112
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC20)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L104
@@L112   EQU   *
         L     12,0(,10)
         MVC   120(4,13),=F'0'
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),112(13)
         MVC   96(4,13),116(13)
         LA    2,120(,13)
         ST    2,100(13)
         MVC   104(4,13),12(11)
         MVC   108(4,13),16(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,124(13)
         L     2,124(13)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L113
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         L     2,0(11)
         MVC   4(4,2),=F'1'
         MVC   128(4,13),=F'1'
         B     @@L104
@@L113   EQU   *
         L     12,0(,10)
         L     2,124(13)
         LTR   2,2
         BE    @@L114
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L104
@@L114   EQU   *
         L     12,0(,10)
         L     2,120(13)
         CL    2,116(13)
         BNH   @@L115
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC21)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L104
@@L115   EQU   *
         L     12,0(,10)
         L     3,0(11)
         L     2,0(11)
         L     2,20(2)
         A     2,=F'1'
         ST    2,20(3)
         L     2,0(11)
         MVC   4(4,2),=F'0'
         L     2,8(11)
         LTR   2,2
         BE    @@L116
         L     2,8(11)
         MVC   0(4,2),120(13)
@@L116   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LTR   2,2
         BE    @@L117
         L     2,4(11)
         MVC   0(4,2),112(13)
         B     @@L118
@@L117   EQU   *
         L     12,0(,10)
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
@@L118   EQU   *
         L     12,0(,10)
         MVC   128(4,13),=F'0'
@@L104   EQU   *
         L     12,0(,10)
         L     15,128(13)
* Function rs_read_record epilogue
         PDPEPIL
* Function rs_read_record literal pool
         DS    0F
         LTORG
* Function rs_read_record page table
         DS    0F
@@PGT14  EQU   *
         DC    A(@@PG14)
         DS    0F
* X-func rs_free_record prologue
RS@FREE@ PDPPRLG CINDEX=15,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN15
         LTORG
@@FEN15  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG15   EQU   *
         LR    11,1
         L     10,=A(@@PGT15)
* Function rs_free_record code
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
* Function rs_free_record epilogue
         PDPEPIL
* Function rs_free_record literal pool
         DS    0F
         LTORG
* Function rs_free_record page table
         DS    0F
@@PGT15  EQU   *
         DC    A(@@PG15)
         DS    0F
* Function fixed_record_format,F11 prologue
@@F11    PDPPRLG CINDEX=16,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN16
         LTORG
@@FEN16  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG16   EQU   *
         LR    11,1
         L     10,=A(@@PGT16)
* Function fixed_record_format code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L121
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'C6'
         BNE   @@L121
         MVC   88(4,13),=F'1'
@@L121   EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function fixed_record_format epilogue
         PDPEPIL
* Function fixed_record_format literal pool
         DS    0F
         LTORG
* Function fixed_record_format page table
         DS    0F
@@PGT16  EQU   *
         DC    A(@@PG16)
@@LC22   EQU   *
         DC    C'RecordSet is not open for writing'
         DC    X'0'
@@LC23   EQU   *
         DC    C'RecordSet write has no record data'
         DC    X'0'
@@LC24   EQU   *
         DC    C'Record exceeds fixed MVS LRECL'
         DC    X'0'
@@LC25   EQU   *
         DC    C'RecordSet fixed-record allocation failed'
         DC    X'0'
@@LC26   EQU   *
         DC    C'Record exceeds MVS maximum LRECL'
         DC    X'0'
         DS    0F
* X-func rs_write_record prologue
RS@WRITE PDPPRLG CINDEX=17,FRAME=136,BASER=12,ENTRY=YES
         B     @@FEN17
         LTORG
@@FEN17  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG17   EQU   *
         LR    11,1
         L     10,=A(@@PGT17)
* Function rs_write_record code
         L     2,0(11)
         LTR   2,2
         BE    @@L124
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L123
@@L124   EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L123   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L125
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC22)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L125   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L126
         L     2,4(11)
         LTR   2,2
         BNE   @@L126
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC23)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L126   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F11)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L127
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BE    @@L127
         L     2,0(11)
         L     2,340(2)
         CL    2,8(11)
         BNL   @@L128
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC24)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L128   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   128(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L129
         MVC   128(4,13),=F'1'
@@L129   EQU   *
         L     12,0(,10)
         MVC   88(4,13),128(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,116(13)
         L     2,116(13)
         LTR   2,2
         BNE   @@L130
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC25)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L130   EQU   *
         L     12,0(,10)
         MVC   120(4,13),=F'0'
@@L131   EQU   *
         L     2,0(11)
         L     2,340(2)
         CL    2,120(13)
         BNH   @@L132
         L     2,116(13)
         A     2,120(13)
         MVI   0(2),64
         L     2,120(13)
         A     2,=F'1'
         ST    2,120(13)
         B     @@L131
@@L132   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L134
         MVC   88(4,13),116(13)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         LA    1,88(,13)
         L     15,=V(MEMCPY)
         BALR  14,15
@@L134   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),116(13)
         L     2,0(11)
         MVC   96(4,13),340(2)
         MVC   100(4,13),12(11)
         MVC   104(4,13),16(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
         MVC   88(4,13),116(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         B     @@L135
@@L127   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BE    @@L136
         L     2,0(11)
         L     2,340(2)
         CL    2,8(11)
         BNL   @@L136
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC26)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L122
@@L136   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         MVC   100(4,13),12(11)
         MVC   104(4,13),16(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
@@L135   EQU   *
         L     12,0(,10)
         L     2,112(13)
         LTR   2,2
         BE    @@L137
         MVC   124(4,13),=F'3'
         B     @@L122
@@L137   EQU   *
         L     12,0(,10)
         L     3,0(11)
         L     2,0(11)
         L     2,20(2)
         A     2,=F'1'
         ST    2,20(3)
         L     2,0(11)
         MVC   4(4,2),=F'0'
         MVC   124(4,13),=F'0'
@@L122   EQU   *
         L     12,0(,10)
         L     15,124(13)
* Function rs_write_record epilogue
         PDPEPIL
* Function rs_write_record literal pool
         DS    0F
         LTORG
* Function rs_write_record page table
         DS    0F
@@PGT17  EQU   *
         DC    A(@@PG17)
@@LC27   EQU   *
         DC    C'Record positioning is only defined for input Rec'
         DC    C'ordSets'
         DC    X'0'
@@LC28   EQU   *
         DC    C'RecordSet positions are one-based'
         DC    X'0'
@@LC29   EQU   *
         DC    C'RecordSet positioning buffer allocation failed'
         DC    X'0'
@@LC30   EQU   *
         DC    C'RecordSet position is beyond end of data'
         DC    X'0'
         DS    0F
* X-func rs_position_record prologue
RS@POSIT PDPPRLG CINDEX=18,FRAME=144,BASER=12,ENTRY=YES
         B     @@FEN18
         LTORG
@@FEN18  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG18   EQU   *
         LR    11,1
         L     10,=A(@@PGT18)
* Function rs_position_record code
         L     2,0(11)
         LTR   2,2
         BE    @@L140
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L139
@@L140   EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L139   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L141
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC27)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L141   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LTR   2,2
         BNE   @@L142
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC28)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L142   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,20(2)
         CL    2,4(11)
         BNE   @@L143
         MVC   132(4,13),=F'0'
         B     @@L138
@@L143   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),8(11)
         MVC   96(4,13),12(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,128(13)
         L     2,128(13)
         LTR   2,2
         BE    @@L144
         MVC   132(4,13),=F'3'
         B     @@L138
@@L144   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   20(4,2),=F'1'
         L     2,0(11)
         MVC   4(4,2),=F'0'
         L     2,4(11)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L145
         MVC   132(4,13),=F'0'
         B     @@L138
@@L145   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   136(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L146
         MVC   136(4,13),=F'32760'
@@L146   EQU   *
         L     12,0(,10)
         MVC   124(4,13),136(13)
         MVC   140(4,13),124(13)
         L     2,124(13)
         LTR   2,2
         BNE   @@L147
         MVC   140(4,13),=F'1'
@@L147   EQU   *
         L     12,0(,10)
         MVC   88(4,13),140(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,120(13)
         L     2,120(13)
         LTR   2,2
         BNE   @@L148
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC29)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L148   EQU   *
         L     12,0(,10)
         MVC   112(4,13),=F'1'
@@L149   EQU   *
         L     2,112(13)
         CL    2,4(11)
         BNL   @@L150
         MVC   116(4,13),=F'0'
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),120(13)
         MVC   96(4,13),124(13)
         LA    2,116(,13)
         ST    2,100(13)
         MVC   104(4,13),8(11)
         MVC   108(4,13),12(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,128(13)
         L     2,128(13)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L152
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         L     2,0(11)
         MVC   4(4,2),=F'1'
         L     2,0(11)
         MVC   20(4,2),112(13)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC30)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L152   EQU   *
         L     12,0(,10)
         L     2,128(13)
         LTR   2,2
         BE    @@L153
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L138
@@L153   EQU   *
         L     12,0(,10)
         L     3,0(11)
         L     2,0(11)
         L     2,20(2)
         A     2,=F'1'
         ST    2,20(3)
         L     2,112(13)
         A     2,=F'1'
         ST    2,112(13)
         B     @@L149
@@L150   EQU   *
         L     12,0(,10)
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   132(4,13),=F'0'
@@L138   EQU   *
         L     12,0(,10)
         L     15,132(13)
* Function rs_position_record epilogue
         PDPEPIL
* Function rs_position_record literal pool
         DS    0F
         LTORG
* Function rs_position_record page table
         DS    0F
@@PGT18  EQU   *
         DC    A(@@PG18)
         DS    0F
* X-func rs_record_number prologue
RS@RECOR PDPPRLG CINDEX=19,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN19
         LTORG
@@FEN19  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG19   EQU   *
         LR    11,1
         L     10,=A(@@PGT19)
* Function rs_record_number code
         L     2,0(11)
         LTR   2,2
         BE    @@L155
         L     2,0(11)
         MVC   88(4,13),20(2)
         B     @@L156
@@L155   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'0'
@@L156   EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function rs_record_number epilogue
         PDPEPIL
* Function rs_record_number literal pool
         DS    0F
         LTORG
* Function rs_record_number page table
         DS    0F
@@PGT19  EQU   *
         DC    A(@@PG19)
         DS    0F
* X-func rs_record_count prologue
RS@RECOR PDPPRLG CINDEX=20,FRAME=112,BASER=12,ENTRY=YES
         B     @@FEN20
         LTORG
@@FEN20  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG20   EQU   *
         LR    11,1
         L     10,=A(@@PGT20)
* Function rs_record_count code
         L     2,4(11)
         LTR   2,2
         BE    @@L158
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L158   EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L160
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L159
@@L160   EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   108(4,13),=F'3'
         B     @@L157
@@L159   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   88(4,13),24(2)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         MVC   100(4,13),12(11)
         LA    1,88(,13)
         L     15,=V(MVSRS@DR)
         BALR  14,15
         LR    2,15
         ST    2,104(13)
         L     2,104(13)
         LTR   2,2
         BNE   @@L161
         MVC   108(4,13),=F'0'
         B     @@L157
@@L161   EQU   *
         L     12,0(,10)
         L     2,104(13)
         LA    3,2(0,0)
         CLR   2,3
         BE    @@L163
         L     2,104(13)
         LA    3,3(0,0)
         CLR   2,3
         BE    @@L163
         B     @@L162
@@L163   EQU   *
         L     12,0(,10)
         MVC   108(4,13),=F'2'
         B     @@L157
@@L162   EQU   *
         L     12,0(,10)
         MVC   108(4,13),=F'3'
@@L157   EQU   *
         L     12,0(,10)
         L     15,108(13)
* Function rs_record_count epilogue
         PDPEPIL
* Function rs_record_count literal pool
         DS    0F
         LTORG
* Function rs_record_count page table
         DS    0F
@@PGT20  EQU   *
         DC    A(@@PG20)
         DS    0F
* X-func rs_eof prologue
RS@EOF   PDPPRLG CINDEX=21,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN21
         LTORG
@@FEN21  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG21   EQU   *
         LR    11,1
         L     10,=A(@@PGT21)
* Function rs_eof code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L165
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L165
         L     2,0(11)
         L     2,4(2)
         LTR   2,2
         BE    @@L165
         MVC   88(4,13),=F'1'
@@L165   EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function rs_eof epilogue
         PDPEPIL
* Function rs_eof literal pool
         DS    0F
         LTORG
* Function rs_eof page table
         DS    0F
@@PGT21  EQU   *
         DC    A(@@PG21)
         DS    0F
* Function text_meta,F12 prologue
@@F12    PDPPRLG CINDEX=22,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN22
         LTORG
@@FEN22  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG22   EQU   *
         LR    11,1
         L     10,=A(@@PGT22)
* Function text_meta code
         L     2,0(11)
         LTR   2,2
         BNE   @@L167
         MVC   88(4,13),=A(@@LC0)
         B     @@L166
@@L167   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,6(0,0)
         CLR   2,3
         BH    @@L175
         L     3,=A(@@L176)
         L     2,4(11)
         SLL   2,2
         L     2,0(2,3)
         BR    2
         DS    0F
         DS    0F
         DS    0F
         LTORG
         DS    0F
@@L176   EQU   *
         DC    A(@@L175)
         DC    A(@@L169)
         DC    A(@@L170)
         DC    A(@@L171)
         DC    A(@@L172)
         DC    A(@@L173)
         DC    A(@@L174)
@@L169   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'28'
         ST    2,88(13)
         B     @@L166
@@L170   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'172'
         ST    2,88(13)
         B     @@L166
@@L171   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'181'
         ST    2,88(13)
         B     @@L166
@@L172   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'310'
         ST    2,88(13)
         B     @@L166
@@L173   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'319'
         ST    2,88(13)
         B     @@L166
@@L174   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         B     @@L166
@@L175   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=A(@@LC0)
@@L166   EQU   *
         L     12,0(,10)
         L     15,88(13)
* Function text_meta epilogue
         PDPEPIL
* Function text_meta literal pool
         DS    0F
         LTORG
* Function text_meta page table
         DS    0F
@@PGT22  EQU   *
         DC    A(@@PG22)
         DS    0F
* X-func rs_text_metadata prologue
RS@TEXT@ PDPPRLG CINDEX=23,FRAME=128,BASER=12,ENTRY=YES
         B     @@FEN23
         LTORG
@@FEN23  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG23   EQU   *
         LR    11,1
         L     10,=A(@@PGT23)
* Function rs_text_metadata code
         MVC   88(4,13),0(11)
         MVC   92(4,13),4(11)
         LA    1,88(,13)
         L     15,=A(@@F12)
         BALR  14,15
         LR    2,15
         ST    2,104(13)
         MVC   88(4,13),104(13)
         LA    1,88(,13)
         L     15,=V(STRLEN)
         BALR  14,15
         LR    2,15
         ST    2,108(13)
         L     2,16(11)
         LTR   2,2
         BE    @@L178
         L     2,16(11)
         MVC   0(4,2),108(13)
@@L178   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L179
         L     2,12(11)
         LTR   2,2
         BE    @@L179
         L     2,12(11)
         BCTR  2,0
         MVC   120(4,13),108(13)
         ST    2,116(13)
         L     2,116(13)
         CL    2,120(13)
         BNH   @@L180
         MVC   116(4,13),120(13)
@@L180   EQU   *
         L     12,0(,10)
         MVC   112(4,13),116(13)
         L     2,112(13)
         LTR   2,2
         BE    @@L181
         MVC   88(4,13),8(11)
         MVC   92(4,13),104(13)
         MVC   96(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(MEMCPY)
         BALR  14,15
@@L181   EQU   *
         L     12,0(,10)
         L     2,8(11)
         A     2,112(13)
         MVI   0(2),0
@@L179   EQU   *
         L     12,0(,10)
         SLR   2,2
         LR    15,2
* Function rs_text_metadata epilogue
         PDPEPIL
* Function rs_text_metadata literal pool
         DS    0F
         LTORG
* Function rs_text_metadata page table
         DS    0F
@@PGT23  EQU   *
         DC    A(@@PG23)
         DS    0F
* X-func rs_number_metadata prologue
RS@NUMBE PDPPRLG CINDEX=24,FRAME=104,BASER=12,ENTRY=YES
         B     @@FEN24
         LTORG
@@FEN24  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG24   EQU   *
         LR    11,1
         L     10,=A(@@PGT24)
* Function rs_number_metadata code
         L     2,0(11)
         LTR   2,2
         BE    @@L184
         L     2,8(11)
         LTR   2,2
         BNE   @@L183
@@L184   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'3'
         B     @@L182
@@L183   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,101(0,0)
         CLR   2,3
         BNE   @@L185
         L     3,8(11)
         L     2,0(11)
         MVC   0(4,3),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BE    @@L186
         MVC   92(4,13),=F'0'
         B     @@L187
@@L186   EQU   *
         L     12,0(,10)
         MVC   92(4,13),=F'2'
@@L187   EQU   *
         L     12,0(,10)
         MVC   88(4,13),92(13)
         B     @@L182
@@L185   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,102(0,0)
         CLR   2,3
         BNE   @@L188
         L     3,8(11)
         L     2,0(11)
         MVC   0(4,3),344(2)
         L     2,0(11)
         L     2,344(2)
         LTR   2,2
         BE    @@L189
         MVC   96(4,13),=F'0'
         B     @@L190
@@L189   EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'2'
@@L190   EQU   *
         L     12,0(,10)
         MVC   88(4,13),96(13)
         B     @@L182
@@L188   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'3'
@@L182   EQU   *
         L     12,0(,10)
         L     15,88(13)
* Function rs_number_metadata epilogue
         PDPEPIL
* Function rs_number_metadata literal pool
         DS    0F
         LTORG
* Function rs_number_metadata page table
         DS    0F
@@PGT24  EQU   *
         DC    A(@@PG24)
         DS    0F
* X-func rs_is_native_recordset prologue
RS@IS@NA PDPPRLG CINDEX=25,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN25
         LTORG
@@FEN25  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG25   EQU   *
         LR    11,1
         L     10,=A(@@PGT25)
* Function rs_is_native_recordset code
         MVC   88(4,13),0(11)
         L     2,88(13)
         LTR   2,2
         BE    @@L192
         MVC   88(4,13),=F'1'
@@L192   EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function rs_is_native_recordset epilogue
         PDPEPIL
* Function rs_is_native_recordset literal pool
         DS    0F
         LTORG
* Function rs_is_native_recordset page table
         DS    0F
@@PGT25  EQU   *
         DC    A(@@PG25)
         END
