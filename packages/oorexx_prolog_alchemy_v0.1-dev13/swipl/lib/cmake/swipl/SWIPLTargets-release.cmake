#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "swipl::swipl" for configuration "Release"
set_property(TARGET swipl::swipl APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(swipl::swipl PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/swipl/bin/x86_64-linux/swipl"
  )

list(APPEND _cmake_import_check_targets swipl::swipl )
list(APPEND _cmake_import_check_files_for_swipl::swipl "${_IMPORT_PREFIX}/lib/swipl/bin/x86_64-linux/swipl" )

# Import target "swipl::libswipl" for configuration "Release"
set_property(TARGET swipl::libswipl APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(swipl::libswipl PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/swipl/lib/x86_64-linux/libswipl.so.10.0.2"
  IMPORTED_SONAME_RELEASE "libswipl.so.10"
  )

list(APPEND _cmake_import_check_targets swipl::libswipl )
list(APPEND _cmake_import_check_files_for_swipl::libswipl "${_IMPORT_PREFIX}/lib/swipl/lib/x86_64-linux/libswipl.so.10.0.2" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
