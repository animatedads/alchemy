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
* Function native_upper,F2 prologue
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
* Function native_upper code
         L     2,0(11)
         LA    3,128(0,0)
         CR    2,3
         BNH   @@L10
         L     2,0(11)
         LA    3,137(0,0)
         CR    2,3
         BNH   @@L9
@@L10    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,144(0,0)
         CR    2,3
         BNH   @@L11
         L     2,0(11)
         LA    3,153(0,0)
         CR    2,3
         BNH   @@L9
@@L11    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,161(0,0)
         CR    2,3
         BNH   @@L8
         L     2,0(11)
         LA    3,169(0,0)
         CR    2,3
         BNH   @@L9
         B     @@L8
@@L9     EQU   *
         L     12,0(,10)
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
* Function native_upper epilogue
         PDPEPIL
* Function native_upper literal pool
         DS    0F
         LTORG
* Function native_upper page table
         DS    0F
@@PGT1   EQU   *
         DC    A(@@PG1)
         DS    0F
* Function native_alpha_upper,F3 prologue
@@F3     PDPPRLG CINDEX=2,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN2
         LTORG
@@FEN2   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG2    EQU   *
         LR    11,1
         L     10,=A(@@PGT2)
* Function native_alpha_upper code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LA    3,192(0,0)
         CR    2,3
         BNH   @@L15
         L     2,0(11)
         LA    3,201(0,0)
         CR    2,3
         BNH   @@L14
@@L15    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,208(0,0)
         CR    2,3
         BNH   @@L16
         L     2,0(11)
         LA    3,217(0,0)
         CR    2,3
         BNH   @@L14
@@L16    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LA    3,225(0,0)
         CR    2,3
         BNH   @@L13
         L     2,0(11)
         LA    3,233(0,0)
         CR    2,3
         BNH   @@L14
         B     @@L13
@@L14    EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'1'
@@L13    EQU   *
         L     12,0(,10)
         L     2,88(13)
         LR    15,2
* Function native_alpha_upper epilogue
         PDPEPIL
* Function native_alpha_upper literal pool
         DS    0F
         LTORG
* Function native_alpha_upper page table
         DS    0F
@@PGT2   EQU   *
         DC    A(@@PG2)
         DS    0F
* Function rs_streq_ci,F4 prologue
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
* Function rs_streq_ci code
         L     2,0(11)
         LTR   2,2
         BE    @@L19
         L     2,4(11)
         LTR   2,2
         BNE   @@L20
@@L19    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'0'
         B     @@L17
@@L20    EQU   *
         L     12,0(,10)
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L21
         L     2,4(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L21
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
         BE    @@L22
         MVC   96(4,13),=F'0'
         B     @@L17
@@L22    EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'1'
         ST    2,0(11)
         L     2,4(11)
         A     2,=F'1'
         ST    2,4(11)
         B     @@L20
@@L21    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         L     2,0(11)
         L     3,4(11)
         IC    2,0(2)
         CLM   2,1,0(3)
         BNE   @@L23
         MVC   100(4,13),=F'1'
@@L23    EQU   *
         L     12,0(,10)
         MVC   96(4,13),100(13)
@@L17    EQU   *
         L     12,0(,10)
         L     15,96(13)
* Function rs_streq_ci epilogue
         PDPEPIL
* Function rs_streq_ci literal pool
         DS    0F
         LTORG
* Function rs_streq_ci page table
         DS    0F
@@PGT3   EQU   *
         DC    A(@@PG3)
         DS    0F
* Function copy_upper,F5 prologue
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
* Function copy_upper code
         L     2,0(11)
         LTR   2,2
         BE    @@L26
         L     2,4(11)
         LTR   2,2
         BE    @@L26
         L     2,8(11)
         LTR   2,2
         BE    @@L26
         L     2,12(11)
         A     2,=F'1'
         CL    2,4(11)
         BH    @@L26
         B     @@L25
@@L26    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L24
@@L25    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'0'
@@L27    EQU   *
         L     2,96(13)
         CL    2,12(11)
         BNL   @@L28
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
         B     @@L27
@@L28    EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,12(11)
         MVI   0(2),0
         MVC   100(4,13),=F'1'
@@L24    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function copy_upper epilogue
         PDPEPIL
* Function copy_upper literal pool
         DS    0F
         LTORG
* Function copy_upper page table
         DS    0F
@@PGT4   EQU   *
         DC    A(@@PG4)
         DS    0F
* Function is_dd_first,F6 prologue
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
* Function is_dd_first code
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=A(@@F2)
         BALR  14,15
         LR    2,15
         ST    2,0(11)
         MVC   96(4,13),=F'0'
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=A(@@F3)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L32
         L     2,0(11)
         LA    3,124(0,0)
         CLR   2,3
         BE    @@L32
         L     2,0(11)
         LA    3,123(0,0)
         CLR   2,3
         BE    @@L32
         L     2,0(11)
         LA    3,91(0,0)
         CLR   2,3
         BE    @@L32
         B     @@L31
@@L32    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L31    EQU   *
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
@@PGT5   EQU   *
         DC    A(@@PG5)
         DS    0F
* Function is_dd_rest,F7 prologue
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
         L     15,=A(@@F6)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L35
         L     2,0(11)
         LA    3,239(0,0)
         CR    2,3
         BNH   @@L34
         L     2,0(11)
         LA    3,249(0,0)
         CR    2,3
         BNH   @@L35
         B     @@L34
@@L35    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L34    EQU   *
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
@@PGT6   EQU   *
         DC    A(@@PG6)
         DS    0F
* Function valid_dd,F8 prologue
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
* Function valid_dd code
         L     2,0(11)
         LTR   2,2
         BE    @@L38
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L38
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F6)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L37
@@L38    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L36
@@L37    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L39    EQU   *
         L     2,0(11)
         A     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L40
         L     2,96(13)
         LA    3,7(0,0)
         CLR   2,3
         BH    @@L43
         L     2,0(11)
         A     2,96(13)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F7)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L41
@@L43    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L36
@@L41    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L39
@@L40    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'1'
@@L36    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function valid_dd epilogue
         PDPEPIL
* Function valid_dd literal pool
         DS    0F
         LTORG
* Function valid_dd page table
         DS    0F
@@PGT7   EQU   *
         DC    A(@@PG7)
         DS    0F
* Function valid_ds_qualifier,F9 prologue
@@F9     PDPPRLG CINDEX=8,FRAME=104,BASER=12,ENTRY=NO
         B     @@FEN8
         LTORG
@@FEN8   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG8    EQU   *
         LR    11,1
         L     10,=A(@@PGT8)
* Function valid_ds_qualifier code
         L     2,4(11)
         LTR   2,2
         BE    @@L46
         L     2,4(11)
         LA    3,8(0,0)
         CLR   2,3
         BH    @@L46
         L     2,0(11)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F6)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L45
@@L46    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'0'
         B     @@L44
@@L45    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'1'
@@L47    EQU   *
         L     2,96(13)
         CL    2,4(11)
         BNL   @@L48
         L     2,0(11)
         A     2,96(13)
         SLR   3,3
         IC    3,0(2)
         LR    2,3
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F7)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L49
         L     2,0(11)
         A     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'60'
         BE    @@L49
         MVC   100(4,13),=F'0'
         B     @@L44
@@L49    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L47
@@L48    EQU   *
         L     12,0(,10)
         MVC   100(4,13),=F'1'
@@L44    EQU   *
         L     12,0(,10)
         L     15,100(13)
* Function valid_ds_qualifier epilogue
         PDPEPIL
* Function valid_ds_qualifier literal pool
         DS    0F
         LTORG
* Function valid_ds_qualifier page table
         DS    0F
@@PGT8   EQU   *
         DC    A(@@PG8)
         DS    0F
* Function valid_dataset,F10 prologue
@@F10    PDPPRLG CINDEX=9,FRAME=112,BASER=12,ENTRY=NO
         B     @@FEN9
         LTORG
@@FEN9   EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG9    EQU   *
         LR    11,1
         L     10,=A(@@PGT9)
* Function valid_dataset code
         L     2,0(11)
         LTR   2,2
         BE    @@L53
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L52
@@L53    EQU   *
         L     12,0(,10)
         MVC   104(4,13),=F'0'
         B     @@L51
@@L52    EQU   *
         L     12,0(,10)
         MVC   96(4,13),0(11)
         MVC   100(4,13),96(13)
@@L54    EQU   *
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'4B'
         BE    @@L57
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L56
@@L57    EQU   *
         L     12,0(,10)
         MVC   88(4,13),100(13)
         L     2,96(13)
         S     2,100(13)
         ST    2,92(13)
         LA    1,88(,13)
         L     15,=A(@@F9)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L58
         MVC   104(4,13),=F'0'
         B     @@L51
@@L58    EQU   *
         L     12,0(,10)
         L     2,96(13)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L59
         B     @@L55
@@L59    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,100(13)
@@L56    EQU   *
         L     12,0(,10)
         L     2,96(13)
         A     2,=F'1'
         ST    2,96(13)
         B     @@L54
@@L55    EQU   *
         L     12,0(,10)
         MVC   104(4,13),=F'1'
@@L51    EQU   *
         L     12,0(,10)
         L     15,104(13)
* Function valid_dataset epilogue
         PDPEPIL
* Function valid_dataset literal pool
         DS    0F
         LTORG
* Function valid_dataset page table
         DS    0F
@@PGT9   EQU   *
         DC    A(@@PG9)
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
* Function parse_resource,F11 prologue
@@F11    PDPPRLG CINDEX=10,FRAME=136,BASER=12,ENTRY=NO
         B     @@FEN10
         LTORG
@@FEN10  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG10   EQU   *
         LR    11,1
         L     10,=A(@@PGT10)
* Function parse_resource code
         L     2,0(11)
         LTR   2,2
         BE    @@L62
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BNE   @@L61
@@L62    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC1)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L61    EQU   *
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
         BNH   @@L63
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC2)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L63    EQU   *
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
         BNH   @@L64
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
         BNE   @@L64
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
         BNE   @@L64
         LA    2,2(0,0)
         A     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'7A'
         BNE   @@L64
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
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L66
         L     2,4(11)
         A     2,=F'172'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F8)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L65
@@L66    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC3)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L65    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'1'
         MVC   128(4,13),=F'0'
         B     @@L60
@@L64    EQU   *
         L     12,0(,10)
         MVC   104(4,13),0(11)
         L     2,0(11)
         A     2,120(13)
         ST    2,108(13)
         L     2,120(13)
         LA    3,1(0,0)
         CLR   2,3
         BNH   @@L67
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'7D'
         BNE   @@L67
         L     3,=F'-1'
         L     2,0(11)
         A     2,120(13)
         AR    2,3
         IC    2,0(2)
         CLM   2,1,=XL1'7D'
         BNE   @@L67
         L     2,104(13)
         A     2,=F'1'
         ST    2,104(13)
         L     2,108(13)
         BCTR  2,0
         ST    2,108(13)
@@L67    EQU   *
         L     12,0(,10)
         L     2,104(13)
         CL    2,108(13)
         BNE   @@L68
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC4)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L68    EQU   *
         L     12,0(,10)
         MVC   112(4,13),=F'0'
         MVC   116(4,13),=F'0'
         MVC   124(4,13),104(13)
@@L69    EQU   *
         L     2,124(13)
         CL    2,108(13)
         BNL   @@L70
         L     2,124(13)
         IC    2,0(2)
         CLM   2,1,=XL1'4D'
         BNE   @@L72
         L     2,112(13)
         LTR   2,2
         BE    @@L73
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC5)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L73    EQU   *
         L     12,0(,10)
         MVC   112(4,13),124(13)
         B     @@L71
@@L72    EQU   *
         L     12,0(,10)
         L     2,124(13)
         IC    2,0(2)
         CLM   2,1,=XL1'5D'
         BNE   @@L71
         MVC   116(4,13),124(13)
@@L71    EQU   *
         L     12,0(,10)
         L     2,124(13)
         A     2,=F'1'
         ST    2,124(13)
         B     @@L69
@@L70    EQU   *
         L     12,0(,10)
         L     2,112(13)
         LTR   2,2
         BE    @@L76
         L     2,108(13)
         BCTR  2,0
         CL    2,116(13)
         BNE   @@L78
         L     2,112(13)
         A     2,=F'1'
         CL    2,116(13)
         BNL   @@L78
         B     @@L77
@@L78    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC5)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L77    EQU   *
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
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L80
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
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L79
@@L80    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC6)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L79    EQU   *
         L     12,0(,10)
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F10)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L82
         L     2,4(11)
         A     2,=F'310'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F8)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L81
@@L82    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC7)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L81    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'3'
         B     @@L83
@@L76    EQU   *
         L     12,0(,10)
         L     2,116(13)
         LTR   2,2
         BNE   @@L85
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         MVC   92(4,13),=F'129'
         MVC   96(4,13),104(13)
         L     2,108(13)
         S     2,104(13)
         ST    2,100(13)
         LA    1,88(,13)
         L     15,=A(@@F5)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L85
         L     2,4(11)
         A     2,=F'181'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F10)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L84
@@L85    EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC8)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L60
@@L84    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   16(4,2),=F'2'
@@L83    EQU   *
         L     12,0(,10)
         MVC   128(4,13),=F'0'
@@L60    EQU   *
         L     12,0(,10)
         L     15,128(13)
* Function parse_resource epilogue
         PDPEPIL
* Function parse_resource literal pool
         DS    0F
         LTORG
* Function parse_resource page table
         DS    0F
@@PGT10  EQU   *
         DC    A(@@PG10)
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
RS@MODE@ PDPPRLG CINDEX=11,FRAME=104,BASER=12,ENTRY=YES
         B     @@FEN11
         LTORG
@@FEN11  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG11   EQU   *
         LR    11,1
         L     10,=A(@@PGT11)
* Function rs_mode_from_text code
         L     2,4(11)
         LTR   2,2
         BNE   @@L87
         MVC   96(4,13),=F'3'
         B     @@L86
@@L87    EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L89
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'00'
         BE    @@L89
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC9)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L89
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC10)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L89
         B     @@L88
@@L89    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'1'
         MVC   96(4,13),=F'0'
         B     @@L86
@@L88    EQU   *
         L     12,0(,10)
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC11)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L91
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC12)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L91
         B     @@L90
@@L91    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'2'
         MVC   96(4,13),=F'0'
         B     @@L86
@@L90    EQU   *
         L     12,0(,10)
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC13)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L93
         MVC   88(4,13),0(11)
         MVC   92(4,13),=A(@@LC14)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L93
         B     @@L92
@@L93    EQU   *
         L     12,0(,10)
         L     2,4(11)
         MVC   0(4,2),=F'3'
         MVC   96(4,13),=F'0'
         B     @@L86
@@L92    EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'3'
@@L86    EQU   *
         L     12,0(,10)
         L     15,96(13)
* Function rs_mode_from_text epilogue
         PDPEPIL
* Function rs_mode_from_text literal pool
         DS    0F
         LTORG
* Function rs_mode_from_text page table
         DS    0F
@@PGT11  EQU   *
         DC    A(@@PG11)
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
RS@OPEN  PDPPRLG CINDEX=12,FRAME=200,BASER=12,ENTRY=YES
         B     @@FEN12
         LTORG
@@FEN12  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG12   EQU   *
         LR    11,1
         L     10,=A(@@PGT12)
* Function rs_open code
         L     2,8(11)
         LTR   2,2
         BNE   @@L95
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC15)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L94
@@L95    EQU   *
         L     12,0(,10)
         L     2,8(11)
         MVC   0(4,2),=F'0'
         L     2,4(11)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L96
         L     2,4(11)
         LA    3,2(0,0)
         CLR   2,3
         BE    @@L96
         L     2,4(11)
         LA    3,3(0,0)
         CLR   2,3
         BE    @@L96
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC16)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L94
@@L96    EQU   *
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
         BNE   @@L97
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC17)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L94
@@L97    EQU   *
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
         L     15,=A(@@F11)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L98
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L94
@@L98    EQU   *
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
         BE    @@L99
         L     2,112(13)
         A     2,=F'172'
         ST    2,184(13)
         B     @@L100
@@L99    EQU   *
         L     12,0(,10)
         MVC   184(4,13),=F'0'
@@L100   EQU   *
         L     12,0(,10)
         MVC   128(4,13),184(13)
         L     2,112(13)
         IC    2,181(2)
         CLM   2,1,=XL1'00'
         BE    @@L101
         L     3,112(13)
         A     3,=F'181'
         ST    3,188(13)
         B     @@L102
@@L101   EQU   *
         L     12,0(,10)
         MVC   188(4,13),=F'0'
@@L102   EQU   *
         L     12,0(,10)
         MVC   132(4,13),188(13)
         L     2,112(13)
         IC    2,310(2)
         CLM   2,1,=XL1'00'
         BE    @@L103
         L     2,112(13)
         A     2,=F'310'
         ST    2,192(13)
         B     @@L104
@@L103   EQU   *
         L     12,0(,10)
         MVC   192(4,13),=F'0'
@@L104   EQU   *
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
         BE    @@L105
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   180(4,13),=F'3'
         B     @@L94
@@L105   EQU   *
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
         L     15,=A(@@F5)
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
         L     15,=A(@@F5)
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
@@L94    EQU   *
         L     12,0(,10)
         L     15,180(13)
* Function rs_open epilogue
         PDPEPIL
* Function rs_open literal pool
         DS    0F
         LTORG
* Function rs_open page table
         DS    0F
@@PGT12  EQU   *
         DC    A(@@PG12)
         DS    0F
* X-func rs_close prologue
RS@CLOSE PDPPRLG CINDEX=13,FRAME=112,BASER=12,ENTRY=YES
         B     @@FEN13
         LTORG
@@FEN13  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG13   EQU   *
         LR    11,1
         L     10,=A(@@PGT13)
* Function rs_close code
         L     2,0(11)
         LTR   2,2
         BNE   @@L107
         B     @@L106
@@L107   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L108
         L     2,0(11)
         L     2,24(2)
         LTR   2,2
         BE    @@L108
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
@@L108   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   0(4,2),=F'0'
         MVC   88(4,13),0(11)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
@@L106   EQU   *
         L     12,0(,10)
* Function rs_close epilogue
         PDPEPIL
* Function rs_close literal pool
         DS    0F
         LTORG
* Function rs_close page table
         DS    0F
@@PGT13  EQU   *
         DC    A(@@PG13)
         DS    0F
* X-func rs_is_open prologue
RS@IS@OP PDPPRLG CINDEX=14,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN14
         LTORG
@@FEN14  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG14   EQU   *
         LR    11,1
         L     10,=A(@@PGT14)
* Function rs_is_open code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L110
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L110
         MVC   88(4,13),=F'1'
@@L110   EQU   *
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
@@PGT14  EQU   *
         DC    A(@@PG14)
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
RS@READ@ PDPPRLG CINDEX=15,FRAME=144,BASER=12,ENTRY=YES
         B     @@FEN15
         LTORG
@@FEN15  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG15   EQU   *
         LR    11,1
         L     10,=A(@@PGT15)
* Function rs_read_record code
         L     2,4(11)
         LTR   2,2
         BE    @@L112
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L112   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L113
         L     2,8(11)
         MVC   0(4,2),=F'0'
@@L113   EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L115
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L114
@@L115   EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L111
@@L114   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L116
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC19)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L111
@@L116   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   132(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L117
         MVC   132(4,13),=F'32760'
@@L117   EQU   *
         L     12,0(,10)
         MVC   116(4,13),132(13)
         MVC   136(4,13),116(13)
         L     2,116(13)
         LTR   2,2
         BNE   @@L118
         MVC   136(4,13),=F'1'
@@L118   EQU   *
         L     12,0(,10)
         MVC   88(4,13),136(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,112(13)
         L     2,112(13)
         LTR   2,2
         BNE   @@L119
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC20)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L111
@@L119   EQU   *
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
         BNE   @@L120
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         L     2,0(11)
         MVC   4(4,2),=F'1'
         MVC   128(4,13),=F'1'
         B     @@L111
@@L120   EQU   *
         L     12,0(,10)
         L     2,124(13)
         LTR   2,2
         BE    @@L121
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   128(4,13),=F'3'
         B     @@L111
@@L121   EQU   *
         L     12,0(,10)
         L     2,120(13)
         CL    2,116(13)
         BNH   @@L122
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
         B     @@L111
@@L122   EQU   *
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
         BE    @@L123
         L     2,8(11)
         MVC   0(4,2),120(13)
@@L123   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LTR   2,2
         BE    @@L124
         L     2,4(11)
         MVC   0(4,2),112(13)
         B     @@L125
@@L124   EQU   *
         L     12,0(,10)
         MVC   88(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
@@L125   EQU   *
         L     12,0(,10)
         MVC   128(4,13),=F'0'
@@L111   EQU   *
         L     12,0(,10)
         L     15,128(13)
* Function rs_read_record epilogue
         PDPEPIL
* Function rs_read_record literal pool
         DS    0F
         LTORG
* Function rs_read_record page table
         DS    0F
@@PGT15  EQU   *
         DC    A(@@PG15)
         DS    0F
* X-func rs_free_record prologue
RS@FREE@ PDPPRLG CINDEX=16,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN16
         LTORG
@@FEN16  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG16   EQU   *
         LR    11,1
         L     10,=A(@@PGT16)
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
@@PGT16  EQU   *
         DC    A(@@PG16)
         DS    0F
* Function fixed_record_format,F12 prologue
@@F12    PDPPRLG CINDEX=17,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN17
         LTORG
@@FEN17  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG17   EQU   *
         LR    11,1
         L     10,=A(@@PGT17)
* Function fixed_record_format code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L128
         L     2,0(11)
         IC    2,0(2)
         CLM   2,1,=XL1'C6'
         BNE   @@L128
         MVC   88(4,13),=F'1'
@@L128   EQU   *
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
@@PGT17  EQU   *
         DC    A(@@PG17)
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
         DC    C'V'
         DC    X'0'
@@LC27   EQU   *
         DC    C'VB'
         DC    X'0'
@@LC28   EQU   *
         DC    C'Record exceeds MVS maximum logical payload lengt'
         DC    C'h'
         DC    X'0'
         DS    0F
* X-func rs_write_record prologue
RS@WRITE PDPPRLG CINDEX=18,FRAME=136,BASER=12,ENTRY=YES
         B     @@FEN18
         LTORG
@@FEN18  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG18   EQU   *
         LR    11,1
         L     10,=A(@@PGT18)
* Function rs_write_record code
         L     2,0(11)
         LTR   2,2
         BE    @@L131
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L130
@@L131   EQU   *
         L     12,0(,10)
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L130   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L132
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC22)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L132   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L133
         L     2,4(11)
         LTR   2,2
         BNE   @@L133
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC23)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L133   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         LA    1,88(,13)
         L     15,=A(@@F12)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BE    @@L134
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BE    @@L134
         L     2,0(11)
         L     2,340(2)
         CL    2,8(11)
         BNL   @@L135
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC24)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L135   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   128(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L136
         MVC   128(4,13),=F'1'
@@L136   EQU   *
         L     12,0(,10)
         MVC   88(4,13),128(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,116(13)
         L     2,116(13)
         LTR   2,2
         BNE   @@L137
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC25)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L137   EQU   *
         L     12,0(,10)
         MVC   120(4,13),=F'0'
@@L138   EQU   *
         L     2,0(11)
         L     2,340(2)
         CL    2,120(13)
         BNH   @@L139
         L     2,116(13)
         A     2,120(13)
         MVI   0(2),64
         L     2,120(13)
         A     2,=F'1'
         ST    2,120(13)
         B     @@L138
@@L139   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L141
         MVC   88(4,13),116(13)
         MVC   92(4,13),4(11)
         MVC   96(4,13),8(11)
         LA    1,88(,13)
         L     15,=V(MEMCPY)
         BALR  14,15
@@L141   EQU   *
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
         B     @@L142
@@L134   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   120(4,13),340(2)
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         MVC   92(4,13),=A(@@LC26)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L144
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         MVC   92(4,13),=A(@@LC27)
         LA    1,88(,13)
         L     15,=A(@@F4)
         BALR  14,15
         LR    2,15
         LTR   2,2
         BNE   @@L144
         B     @@L143
@@L144   EQU   *
         L     12,0(,10)
         L     2,120(13)
         LA    3,3(0,0)
         CLR   2,3
         BNH   @@L143
         L     2,120(13)
         A     2,=F'-4'
         ST    2,120(13)
@@L143   EQU   *
         L     12,0(,10)
         L     2,120(13)
         LTR   2,2
         BE    @@L145
         L     2,8(11)
         CL    2,120(13)
         BNH   @@L145
         MVC   88(4,13),12(11)
         MVC   92(4,13),16(11)
         MVC   96(4,13),=A(@@LC28)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   124(4,13),=F'3'
         B     @@L129
@@L145   EQU   *
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
@@L142   EQU   *
         L     12,0(,10)
         L     2,112(13)
         LTR   2,2
         BE    @@L146
         MVC   124(4,13),=F'3'
         B     @@L129
@@L146   EQU   *
         L     12,0(,10)
         L     3,0(11)
         L     2,0(11)
         L     2,20(2)
         A     2,=F'1'
         ST    2,20(3)
         L     2,0(11)
         MVC   4(4,2),=F'0'
         MVC   124(4,13),=F'0'
@@L129   EQU   *
         L     12,0(,10)
         L     15,124(13)
* Function rs_write_record epilogue
         PDPEPIL
* Function rs_write_record literal pool
         DS    0F
         LTORG
* Function rs_write_record page table
         DS    0F
@@PGT18  EQU   *
         DC    A(@@PG18)
@@LC29   EQU   *
         DC    C'Record positioning is only defined for input Rec'
         DC    C'ordSets'
         DC    X'0'
@@LC30   EQU   *
         DC    C'RecordSet positions are one-based'
         DC    X'0'
@@LC31   EQU   *
         DC    C'RecordSet positioning buffer allocation failed'
         DC    X'0'
@@LC32   EQU   *
         DC    C'RecordSet position is beyond end of data'
         DC    X'0'
         DS    0F
* X-func rs_position_record prologue
RS@POSIT PDPPRLG CINDEX=19,FRAME=144,BASER=12,ENTRY=YES
         B     @@FEN19
         LTORG
@@FEN19  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG19   EQU   *
         LR    11,1
         L     10,=A(@@PGT19)
* Function rs_position_record code
         L     2,0(11)
         LTR   2,2
         BE    @@L149
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L148
@@L149   EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L148   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,12(2)
         LA    3,1(0,0)
         CLR   2,3
         BE    @@L150
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC29)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L150   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LTR   2,2
         BNE   @@L151
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC30)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L151   EQU   *
         L     12,0(,10)
         L     2,0(11)
         L     2,20(2)
         CL    2,4(11)
         BNE   @@L152
         MVC   132(4,13),=F'0'
         B     @@L147
@@L152   EQU   *
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
         BE    @@L153
         MVC   132(4,13),=F'3'
         B     @@L147
@@L153   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   20(4,2),=F'1'
         L     2,0(11)
         MVC   4(4,2),=F'0'
         L     2,4(11)
         LA    3,1(0,0)
         CLR   2,3
         BNE   @@L154
         MVC   132(4,13),=F'0'
         B     @@L147
@@L154   EQU   *
         L     12,0(,10)
         L     2,0(11)
         MVC   136(4,13),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BNE   @@L155
         MVC   136(4,13),=F'32760'
@@L155   EQU   *
         L     12,0(,10)
         MVC   124(4,13),136(13)
         MVC   140(4,13),124(13)
         L     2,124(13)
         LTR   2,2
         BNE   @@L156
         MVC   140(4,13),=F'1'
@@L156   EQU   *
         L     12,0(,10)
         MVC   88(4,13),140(13)
         LA    1,88(,13)
         L     15,=V(MALLOC)
         BALR  14,15
         LR    2,15
         ST    2,120(13)
         L     2,120(13)
         LTR   2,2
         BNE   @@L157
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC31)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L157   EQU   *
         L     12,0(,10)
         MVC   112(4,13),=F'1'
@@L158   EQU   *
         L     2,112(13)
         CL    2,4(11)
         BNL   @@L159
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
         BNE   @@L161
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
         MVC   96(4,13),=A(@@LC32)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L161   EQU   *
         L     12,0(,10)
         L     2,128(13)
         LTR   2,2
         BE    @@L162
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   132(4,13),=F'3'
         B     @@L147
@@L162   EQU   *
         L     12,0(,10)
         L     3,0(11)
         L     2,0(11)
         L     2,20(2)
         A     2,=F'1'
         ST    2,20(3)
         L     2,112(13)
         A     2,=F'1'
         ST    2,112(13)
         B     @@L158
@@L159   EQU   *
         L     12,0(,10)
         MVC   88(4,13),120(13)
         LA    1,88(,13)
         L     15,=V(FREE)
         BALR  14,15
         MVC   132(4,13),=F'0'
@@L147   EQU   *
         L     12,0(,10)
         L     15,132(13)
* Function rs_position_record epilogue
         PDPEPIL
* Function rs_position_record literal pool
         DS    0F
         LTORG
* Function rs_position_record page table
         DS    0F
@@PGT19  EQU   *
         DC    A(@@PG19)
         DS    0F
* X-func rs_record_number prologue
RS@RECOR PDPPRLG CINDEX=20,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN20
         LTORG
@@FEN20  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG20   EQU   *
         LR    11,1
         L     10,=A(@@PGT20)
* Function rs_record_number code
         L     2,0(11)
         LTR   2,2
         BE    @@L164
         L     2,0(11)
         MVC   88(4,13),20(2)
         B     @@L165
@@L164   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'0'
@@L165   EQU   *
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
@@PGT20  EQU   *
         DC    A(@@PG20)
         DS    0F
* X-func rs_record_count prologue
RS@RECOR PDPPRLG CINDEX=21,FRAME=112,BASER=12,ENTRY=YES
         B     @@FEN21
         LTORG
@@FEN21  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG21   EQU   *
         LR    11,1
         L     10,=A(@@PGT21)
* Function rs_record_count code
         L     2,4(11)
         LTR   2,2
         BE    @@L167
         L     2,4(11)
         MVC   0(4,2),=F'0'
@@L167   EQU   *
         L     12,0(,10)
         L     2,0(11)
         LTR   2,2
         BE    @@L169
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BNE   @@L168
@@L169   EQU   *
         L     12,0(,10)
         MVC   88(4,13),8(11)
         MVC   92(4,13),12(11)
         MVC   96(4,13),=A(@@LC18)
         LA    1,88(,13)
         L     15,=A(@@F1)
         BALR  14,15
         MVC   108(4,13),=F'3'
         B     @@L166
@@L168   EQU   *
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
         BNE   @@L170
         MVC   108(4,13),=F'0'
         B     @@L166
@@L170   EQU   *
         L     12,0(,10)
         L     2,104(13)
         LA    3,2(0,0)
         CLR   2,3
         BE    @@L172
         L     2,104(13)
         LA    3,3(0,0)
         CLR   2,3
         BE    @@L172
         B     @@L171
@@L172   EQU   *
         L     12,0(,10)
         MVC   108(4,13),=F'2'
         B     @@L166
@@L171   EQU   *
         L     12,0(,10)
         MVC   108(4,13),=F'3'
@@L166   EQU   *
         L     12,0(,10)
         L     15,108(13)
* Function rs_record_count epilogue
         PDPEPIL
* Function rs_record_count literal pool
         DS    0F
         LTORG
* Function rs_record_count page table
         DS    0F
@@PGT21  EQU   *
         DC    A(@@PG21)
         DS    0F
* X-func rs_eof prologue
RS@EOF   PDPPRLG CINDEX=22,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN22
         LTORG
@@FEN22  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG22   EQU   *
         LR    11,1
         L     10,=A(@@PGT22)
* Function rs_eof code
         MVC   88(4,13),=F'0'
         L     2,0(11)
         LTR   2,2
         BE    @@L174
         L     2,0(11)
         L     2,0(2)
         LTR   2,2
         BE    @@L174
         L     2,0(11)
         L     2,4(2)
         LTR   2,2
         BE    @@L174
         MVC   88(4,13),=F'1'
@@L174   EQU   *
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
@@PGT22  EQU   *
         DC    A(@@PG22)
         DS    0F
* Function text_meta,F13 prologue
@@F13    PDPPRLG CINDEX=23,FRAME=96,BASER=12,ENTRY=NO
         B     @@FEN23
         LTORG
@@FEN23  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG23   EQU   *
         LR    11,1
         L     10,=A(@@PGT23)
* Function text_meta code
         L     2,0(11)
         LTR   2,2
         BNE   @@L176
         MVC   88(4,13),=A(@@LC0)
         B     @@L175
@@L176   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,6(0,0)
         CLR   2,3
         BH    @@L184
         L     3,=A(@@L185)
         L     2,4(11)
         SLL   2,2
         L     2,0(2,3)
         BR    2
         DS    0F
         DS    0F
         DS    0F
         LTORG
         DS    0F
@@L185   EQU   *
         DC    A(@@L184)
         DC    A(@@L178)
         DC    A(@@L179)
         DC    A(@@L180)
         DC    A(@@L181)
         DC    A(@@L182)
         DC    A(@@L183)
@@L178   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'28'
         ST    2,88(13)
         B     @@L175
@@L179   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'172'
         ST    2,88(13)
         B     @@L175
@@L180   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'181'
         ST    2,88(13)
         B     @@L175
@@L181   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'310'
         ST    2,88(13)
         B     @@L175
@@L182   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'319'
         ST    2,88(13)
         B     @@L175
@@L183   EQU   *
         L     12,0(,10)
         L     2,0(11)
         A     2,=F'328'
         ST    2,88(13)
         B     @@L175
@@L184   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=A(@@LC0)
@@L175   EQU   *
         L     12,0(,10)
         L     15,88(13)
* Function text_meta epilogue
         PDPEPIL
* Function text_meta literal pool
         DS    0F
         LTORG
* Function text_meta page table
         DS    0F
@@PGT23  EQU   *
         DC    A(@@PG23)
         DS    0F
* X-func rs_text_metadata prologue
RS@TEXT@ PDPPRLG CINDEX=24,FRAME=128,BASER=12,ENTRY=YES
         B     @@FEN24
         LTORG
@@FEN24  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG24   EQU   *
         LR    11,1
         L     10,=A(@@PGT24)
* Function rs_text_metadata code
         MVC   88(4,13),0(11)
         MVC   92(4,13),4(11)
         LA    1,88(,13)
         L     15,=A(@@F13)
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
         BE    @@L187
         L     2,16(11)
         MVC   0(4,2),108(13)
@@L187   EQU   *
         L     12,0(,10)
         L     2,8(11)
         LTR   2,2
         BE    @@L188
         L     2,12(11)
         LTR   2,2
         BE    @@L188
         L     2,12(11)
         BCTR  2,0
         MVC   120(4,13),108(13)
         ST    2,116(13)
         L     2,116(13)
         CL    2,120(13)
         BNH   @@L189
         MVC   116(4,13),120(13)
@@L189   EQU   *
         L     12,0(,10)
         MVC   112(4,13),116(13)
         L     2,112(13)
         LTR   2,2
         BE    @@L190
         MVC   88(4,13),8(11)
         MVC   92(4,13),104(13)
         MVC   96(4,13),112(13)
         LA    1,88(,13)
         L     15,=V(MEMCPY)
         BALR  14,15
@@L190   EQU   *
         L     12,0(,10)
         L     2,8(11)
         A     2,112(13)
         MVI   0(2),0
@@L188   EQU   *
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
@@PGT24  EQU   *
         DC    A(@@PG24)
         DS    0F
* X-func rs_number_metadata prologue
RS@NUMBE PDPPRLG CINDEX=25,FRAME=104,BASER=12,ENTRY=YES
         B     @@FEN25
         LTORG
@@FEN25  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG25   EQU   *
         LR    11,1
         L     10,=A(@@PGT25)
* Function rs_number_metadata code
         L     2,0(11)
         LTR   2,2
         BE    @@L193
         L     2,8(11)
         LTR   2,2
         BNE   @@L192
@@L193   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'3'
         B     @@L191
@@L192   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,101(0,0)
         CLR   2,3
         BNE   @@L194
         L     3,8(11)
         L     2,0(11)
         MVC   0(4,3),340(2)
         L     2,0(11)
         L     2,340(2)
         LTR   2,2
         BE    @@L195
         MVC   92(4,13),=F'0'
         B     @@L196
@@L195   EQU   *
         L     12,0(,10)
         MVC   92(4,13),=F'2'
@@L196   EQU   *
         L     12,0(,10)
         MVC   88(4,13),92(13)
         B     @@L191
@@L194   EQU   *
         L     12,0(,10)
         L     2,4(11)
         LA    3,102(0,0)
         CLR   2,3
         BNE   @@L197
         L     3,8(11)
         L     2,0(11)
         MVC   0(4,3),344(2)
         L     2,0(11)
         L     2,344(2)
         LTR   2,2
         BE    @@L198
         MVC   96(4,13),=F'0'
         B     @@L199
@@L198   EQU   *
         L     12,0(,10)
         MVC   96(4,13),=F'2'
@@L199   EQU   *
         L     12,0(,10)
         MVC   88(4,13),96(13)
         B     @@L191
@@L197   EQU   *
         L     12,0(,10)
         MVC   88(4,13),=F'3'
@@L191   EQU   *
         L     12,0(,10)
         L     15,88(13)
* Function rs_number_metadata epilogue
         PDPEPIL
* Function rs_number_metadata literal pool
         DS    0F
         LTORG
* Function rs_number_metadata page table
         DS    0F
@@PGT25  EQU   *
         DC    A(@@PG25)
         DS    0F
* X-func rs_is_native_recordset prologue
RS@IS@NA PDPPRLG CINDEX=26,FRAME=96,BASER=12,ENTRY=YES
         B     @@FEN26
         LTORG
@@FEN26  EQU   *
         DROP  12
         BALR  12,0
         USING *,12
@@PG26   EQU   *
         LR    11,1
         L     10,=A(@@PGT26)
* Function rs_is_native_recordset code
         MVC   88(4,13),0(11)
         L     2,88(13)
         LTR   2,2
         BE    @@L201
         MVC   88(4,13),=F'1'
@@L201   EQU   *
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
@@PGT26  EQU   *
         DC    A(@@PG26)
         END
