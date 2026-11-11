/* External producer. Any program making the file has the same effect. */
parse arg root
if root='' then root=directory()
path=root||'/input/ready.flag'
call lineout path, 'A separate ooRexx process created this file.'
call stream path, 'C', 'CLOSE'
say 'Created '||path
