# Android native host dev17
Build-only checkpoint from the dev16 host. It isolates Android -> JNI -> RexxCreateInterpreter -> RexxArrayObject -> CallProgram. It deliberately contains no Wire dependencies yet. Logging brackets NewArray(0), CallProgram, and CheckCondition, and the Termux build log is persisted to Download.
