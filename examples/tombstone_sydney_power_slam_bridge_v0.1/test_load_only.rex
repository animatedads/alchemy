/* Intentionally tests acceptance or runtime rejection of one whole PSV. */
parse arg file
if file=='' then exit 9
b=.PowerSlamV5VBridge~new
n=b~load(file)
say 'ACCEPTED' n
exit 0
::requires 'PowerSlamV5VBridge.cls'
