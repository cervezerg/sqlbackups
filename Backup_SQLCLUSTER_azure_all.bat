@echo off
SETLOCAL EnableDelayedExpansion

REM -------------------------------------------------------------------
REM VARIABLES CUSTOMIZABLES
REM -------------------------------------------------------------------

REM *******************************************************************
REM ************               IMPORTANTE  ****************************

REM SE REQUIERE HACER UN LOGIN CON AZCOPY PARA TENER AUTENTICACION ALMACENADA EN ESTA CUENTA
REM REMITIRSE AL ARCHIVO PARA GENERAR AUTH MEDIANTE CERTIFICADO Y APPREGISTRATION

REM *******************************************************************
set zipname=BKPEXAMPLESQL
set bkpfolder=C:\Backups
set trnfolder=C:\Backups\TRN
set instancia=EXAMPLECLUSTERSQL
set logpath=c:\tools
set RUTACONTAINER=https://examplebackupsql.blob.core.windows.net/sqlbackups


REM -------------------------------------------------------------------
REM VARIABLES DEL SCRIPT
REM -------------------------------------------------------------------

REM COMANDO PARA CREAR EL SUFIJO DEL ARCHIVO AAAA_MM_DD_HHHH

set hour=%time: =0%
set fechahora=%date:~-4%_%date:~3,2%_%date:~,2%_%hour:~,2%%hour:~3,2%


REM Nombre completo del archivo ZIP que sera subido
set zipfile=%bkpfolder%\%zipname%_%fechahora%.zip


REM Archivo de Log
set logfile=%logpath%\%zipname%_%fechahora%.txt

REM -------------------------------------------------------------------
REM INICIO DEL PROCESO
REM -------------------------------------------------------------------

echo %date%_%time: =0% Inicio del Proceso >>%logfile%

REM Verifica si 7-zip está instalado
set path=%path%;%programfiles%\7-Zip
7z
if %errorlevel% neq 0 (
	ECHO "No se encuentra instalado 7-zip. No es posible continuar con la tarea">>%logfile%
	echo "Puede descargar 7-zip desde la URL http://www.7-zip.org/">>%logfile%
	goto :fin
)

REM Verifica si azcopy está instalado
azcopy
if %errorlevel% neq 0 (
	ECHO "No se encuentra instalado azcopy. No es posible continuar con la tarea">>%logfile%
	goto :fin
)


REM Obtiene listado de bases de datos en archivo temporal

sqlcmd -E -S %instancia% -d master -Q "EXEC sp_databases" -o %bkpfolder%\dblist.txt

REM Iteracion para realizar los bkps de SQL
FOR /F "eol=( skip=2" %%i IN (%bkpfolder%\dblist.txt) DO (


set bakfile=%bkpfolder%\%%i_%fechahora%.bak>>%logfile%
echo ******************************************************************>>%logfile%
echo ** Script para subir a Azure los archivos de backup SQL           **>>%logfile%
echo ******************************************************************>>%logfile%
echo.
echo -Base de datos: %%i>>%logfile%
echo -Instancia    : %instancia%>>%logfile%
echo.
echo.
echo.
echo %date%_%time: =0% Realizando backup de %%i>>%logfile%

echo.
sqlcmd -E -S %instancia% -d master -Q "BACKUP DATABASE [%%i] TO  DISK = N'!bakfile!' WITH NOINIT,  NAME = N'Backup_%%i_%fechahora%', SKIP, STATS = 10">>%logfile%
echo.>>%logfile% 

)

echo %date%_%time: =0% Backup realizado>>%logfile%
echo %date%_%time: =0% COMPRIMIR LOS ARCHIVOS BAK CON 7ZIP>>%logfile%
echo Comprimiendo backup...>>%logfile%
echo.

7z a -tzip %zipfile% %bkpfolder%\*%fechahora%.bak>>%logfile%
echo %date%_%time: =0% Zip de archivos completado>>%logfile%

REM -------------------------------------------------------------------


echo %date%_%time: =0% Subir archivos a Azure>>%logfile%

azcopy copy %zipfile% %RUTACONTAINER%


echo %date%_%time: =0% Archivo Zip fue subido a Azure>>%logfile%

:fin
echo %date%_%time: =0% BORRAR TEMPORALES>>%logfile%
del %bkpfolder%\dblist.txt

REM ELIMINAR ARCHIVOS ANTIGUOS DE LA CARPETA
echo %date%_%time: =0% Eliminar Archivos antiguos de carpeta>>%logfile%
forfiles -p %bkpfolder% -m %zipname%*.zip -d "-2" -c "cmd /c del @path"
forfiles -p %bkpfolder% -m *.bak -d "-1" -c "cmd /c del @path"
forfiles -p %bkpfolder% -m %zipname%*.txt -d "-10" -c "cmd /c del @path"
forfiles -p %trnfolder% -m *.trn -d "-0" -c "cmd /c del @path"

echo.
echo %date%_%time: =0% Tarea Finalizada>>%logfile%
:fin
echo.
