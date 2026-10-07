/* Cross-platform logical RecordSet object. */

::CLASS 'RecordSet' PUBLIC

::METHOD OPEN CLASS
  use strict arg resource, mode = "READ", options = .nil
  return self~new(resource, mode, options)

::METHOD INIT EXTERNAL "LIBRARY recordset RecordSet_Init"
::METHOD UNINIT EXTERNAL "LIBRARY recordset RecordSet_Uninit"
::METHOD CLOSE EXTERNAL "LIBRARY recordset RecordSet_Close"
::METHOD READ EXTERNAL "LIBRARY recordset RecordSet_Read"
::METHOD WRITE EXTERNAL "LIBRARY recordset RecordSet_Write"
::METHOD READSTEM EXTERNAL "LIBRARY recordset RecordSet_ReadStem"
::METHOD WRITESTEM EXTERNAL "LIBRARY recordset RecordSet_WriteStem"
::METHOD POSITION EXTERNAL "LIBRARY recordset RecordSet_Position"
::METHOD RECORDNUMBER EXTERNAL "LIBRARY recordset RecordSet_RecordNumber"
::METHOD RECORDCOUNT EXTERNAL "LIBRARY recordset RecordSet_RecordCount"
::METHOD EOF EXTERNAL "LIBRARY recordset RecordSet_Eof"
::METHOD ISOPEN EXTERNAL "LIBRARY recordset RecordSet_IsOpen"
::METHOD NAME EXTERNAL "LIBRARY recordset RecordSet_Name"
::METHOD DDNAME EXTERNAL "LIBRARY recordset RecordSet_DdName"
::METHOD DATASETNAME EXTERNAL "LIBRARY recordset RecordSet_DataSetName"
::METHOD MEMBERNAME EXTERNAL "LIBRARY recordset RecordSet_MemberName"
::METHOD ORGANIZATION EXTERNAL "LIBRARY recordset RecordSet_Organization"
::METHOD RECORDFORMAT EXTERNAL "LIBRARY recordset RecordSet_RecordFormat"
::METHOD LOGICALRECORDLENGTH EXTERNAL "LIBRARY recordset RecordSet_LogicalRecordLength"
::METHOD BLOCKSIZE EXTERNAL "LIBRARY recordset RecordSet_BlockSize"
::METHOD ISNATIVERECORDSET EXTERNAL "LIBRARY recordset RecordSet_IsNativeRecordSet"
