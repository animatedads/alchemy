@echo off
rem
rem This script MUST run under NT Command prompt, not 4DOS/NT
rem
if "%COMPUTER_NAME%" == "SNARK" goto snark
set REXXSQL_HOME=\rexxsql
set REXXSQL_DIST=e:\rexxsql\dist
goto start
:snark
set REXXSQL_HOME=\rexxsql
set REXXSQL_DIST=%REXXSQL_HOME%\dist
:start
if "%1x" == "x" goto saw
goto %1
:saw
echo *************************** SQL Anywhere
mkdir %REXXSQL_HOME%\saw\win32\vc\quercus
mkdir %REXXSQL_DIST%\saw\quercus
cd %REXXSQL_HOME%\saw\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SAW INT=QUERCUS
if %ERRORLEVEL% == 0 goto saw-regina
goto error-end

:saw-regina
mkdir %REXXSQL_HOME%\saw\win32\vc\regina
mkdir %REXXSQL_DIST%\saw\regina
cd %REXXSQL_HOME%\saw\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SAW INT=REGINA
if %ERRORLEVEL% == 0 goto saw-orexx
goto error-end

:saw-orexx
mkdir %REXXSQL_HOME%\saw\win32\vc\orexx
mkdir %REXXSQL_DIST%\saw\orexx
cd %REXXSQL_HOME%\saw\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SAW INT=OREXX
if %ERRORLEVEL% == 0 goto saw-winrexx
goto error-end

:saw-winrexx
mkdir %REXXSQL_HOME%\saw\win32\vc\winrexx
mkdir %REXXSQL_DIST%\saw\winrexx
cd %REXXSQL_HOME%\saw\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SAW INT=WINREXX
if %ERRORLEVEL% == 0 goto ora
goto error-end

:ora
echo *************************** Oracle
mkdir %REXXSQL_HOME%\ora\win32\vc\quercus
mkdir %REXXSQL_DIST%\ora\quercus
cd %REXXSQL_HOME%\ora\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ORA INT=QUERCUS
if %ERRORLEVEL% == 0 goto ora-regina
goto error-end

:ora-regina
mkdir %REXXSQL_HOME%\ora\win32\vc\regina
mkdir %REXXSQL_DIST%\ora\regina
cd %REXXSQL_HOME%\ora\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ORA INT=REGINA
if %ERRORLEVEL% == 0 goto ora-orexx
goto error-end

:ora-orexx
mkdir %REXXSQL_HOME%\ora\win32\vc\orexx
mkdir %REXXSQL_DIST%\ora\orexx
cd %REXXSQL_HOME%\ora\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ORA INT=OREXX
if %ERRORLEVEL% == 0 goto ora-winrexx
goto error-end

:ora-winrexx
mkdir %REXXSQL_HOME%\ora\win32\vc\winrexx
mkdir %REXXSQL_DIST%\ora\winrexx
cd %REXXSQL_HOME%\ora\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ORA INT=WINREXX
if %ERRORLEVEL% == 0 goto odbc
goto error-end

:odbc
echo *************************** ODBC
mkdir %REXXSQL_HOME%\odbc\win32\vc\quercus
mkdir %REXXSQL_DIST%\odbc\quercus
cd %REXXSQL_HOME%\odbc\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ODBC INT=QUERCUS
if %ERRORLEVEL% == 0 goto odbc-regina
goto error-end

:odbc-regina
mkdir %REXXSQL_HOME%\odbc\win32\vc\regina
mkdir %REXXSQL_DIST%\odbc\regina
cd %REXXSQL_HOME%\odbc\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ODBC INT=REGINA
if %ERRORLEVEL% == 0 goto odbc-orexx
goto error-end

:odbc-orexx
mkdir %REXXSQL_HOME%\odbc\win32\vc\orexx
mkdir %REXXSQL_DIST%\odbc\orexx
cd %REXXSQL_HOME%\odbc\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ODBC INT=OREXX
if %ERRORLEVEL% == 0 goto odbc-winrexx
goto error-end

:odbc-winrexx
mkdir %REXXSQL_HOME%\odbc\win32\vc\winrexx
mkdir %REXXSQL_DIST%\odbc\winrexx
cd %REXXSQL_HOME%\odbc\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=ODBC INT=WINREXX
if %ERRORLEVEL% == 0 goto sol
goto error-end

:sol
echo *************************** SolidServer
mkdir %REXXSQL_HOME%\sol\win32\vc\quercus
mkdir %REXXSQL_DIST%\sol\quercus
cd %REXXSQL_HOME%\sol\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SOL INT=QUERCUS
if %ERRORLEVEL% == 0 goto sol-regina
goto error-end

:sol-regina
mkdir %REXXSQL_HOME%\sol\win32\vc\regina
mkdir %REXXSQL_DIST%\sol\regina
cd %REXXSQL_HOME%\sol\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SOL INT=REGINA
if %ERRORLEVEL% == 0 goto sol-orexx
goto error-end

:sol-orexx
mkdir %REXXSQL_HOME%\sol\win32\vc\orexx
mkdir %REXXSQL_DIST%\sol\orexx
cd %REXXSQL_HOME%\sol\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SOL INT=OREXX
if %ERRORLEVEL% == 0 goto sol-winrexx
goto error-end

:sol-winrexx
mkdir %REXXSQL_HOME%\sol\win32\vc\winrexx
mkdir %REXXSQL_DIST%\sol\winrexx
cd %REXXSQL_HOME%\sol\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=SOL INT=WINREXX
if %ERRORLEVEL% == 0 goto db2
goto error-end

:db2
echo *************************** DB2
mkdir %REXXSQL_HOME%\db2\win32\vc\quercus
mkdir %REXXSQL_DIST%\db2\quercus
cd %REXXSQL_HOME%\db2\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=DB2 INT=QUERCUS
if %ERRORLEVEL% == 0 goto db2-regina
goto error-end

:db2-regina
mkdir %REXXSQL_HOME%\db2\win32\vc\regina
mkdir %REXXSQL_DIST%\db2\regina
cd %REXXSQL_HOME%\db2\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=DB2 INT=REGINA
if %ERRORLEVEL% == 0 goto db2-orexx
goto error-end

:db2-orexx
mkdir %REXXSQL_HOME%\db2\win32\vc\orexx
mkdir %REXXSQL_DIST%\db2\orexx
cd %REXXSQL_HOME%\db2\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=DB2 INT=OREXX
if %ERRORLEVEL% == 0 goto db2-winrexx
goto error-end

:db2-winrexx
mkdir %REXXSQL_HOME%\db2\win32\vc\winrexx
mkdir %REXXSQL_DIST%\db2\winrexx
cd %REXXSQL_HOME%\db2\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=DB2 INT=WINREXX
if %ERRORLEVEL% == 0 goto udbc

:udbc
echo *************************** UDBC
mkdir %REXXSQL_HOME%\udbc\win32\vc\quercus
mkdir %REXXSQL_DIST%\udbc\quercus
cd %REXXSQL_HOME%\udbc\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=UDBC INT=QUERCUS
if %ERRORLEVEL% == 0 goto udbc-regina
goto error-end

:udbc-regina
mkdir %REXXSQL_HOME%\udbc\win32\vc\regina
mkdir %REXXSQL_DIST%\udbc\regina
cd %REXXSQL_HOME%\udbc\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=UDBC INT=REGINA
if %ERRORLEVEL% == 0 goto udbc-orexx
goto error-end

:udbc-orexx
mkdir %REXXSQL_HOME%\udbc\win32\vc\orexx
mkdir %REXXSQL_DIST%\udbc\orexx
cd %REXXSQL_HOME%\udbc\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=UDBC INT=OREXX
if %ERRORLEVEL% == 0 goto udbc-winrexx
goto error-end

:udbc-winrexx
mkdir %REXXSQL_HOME%\udbc\win32\vc\winrexx
mkdir %REXXSQL_DIST%\udbc\winrexx
cd %REXXSQL_HOME%\udbc\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=UDBC INT=WINREXX
if %ERRORLEVEL% == 0 goto min2
goto error-end

:min2
echo *************************** mSQL 2
mkdir %REXXSQL_HOME%\min2\win32\vc\quercus
mkdir %REXXSQL_DIST%\min2\quercus
cd %REXXSQL_HOME%\min2\win32\vc\quercus
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=MIN2 INT=QUERCUS
if %ERRORLEVEL% == 0 goto min2-regina
goto error-end

:min2-regina
mkdir %REXXSQL_HOME%\min2\win32\vc\regina
mkdir %REXXSQL_DIST%\min2\regina
cd %REXXSQL_HOME%\min2\win32\vc\regina
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=MIN2 INT=REGINA
if %ERRORLEVEL% == 0 goto min2-orexx
goto error-end

:min2-orexx
mkdir %REXXSQL_HOME%\min2\win32\vc\orexx
mkdir %REXXSQL_DIST%\min2\orexx
cd %REXXSQL_HOME%\min2\win32\vc\orexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=MIN2 INT=OREXX
if %ERRORLEVEL% == 0 goto min2-winrexx
goto error-end

:min2-winrexx
mkdir %REXXSQL_HOME%\min2\win32\vc\winrexx
mkdir %REXXSQL_DIST%\min2\winrexx
cd %REXXSQL_HOME%\min2\win32\vc\winrexx
nmake -nologo -f %REXXSQL_HOME%\vcwin32.mak DB=MIN2 INT=WINREXX
if %ERRORLEVEL% == 0 goto end-ok
goto error-end

:error-end
echo error
:end-ok
cd %REXXSQL_HOME%
