         PRINT NOGEN
MASIVP1  CSECT
         USING MASIVP1,15
         B     START
         DC    CL8'MASIVP1 '
START    DS    0H
* DEV3-PRE1 SAFETY STUB.
* BASE-1 may return CC 0000 only after the real TK5 DYN75 calling convention
* is implemented and HELLO/ACCEPT/PING plus 00-FF binary integrity are proven
* against the ooRexx MAS endpoint.  Do not turn this into a synthetic pass.
         LA    15,8
         BR    14
         END   MASIVP1
