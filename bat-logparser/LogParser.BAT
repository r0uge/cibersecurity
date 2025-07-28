@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: Configuración de variables
set "ARCHIVO_ORIGEN=C:\F\filtered_new.csv"
set "ARCHIVO_BACKUP=C:\F\filtered_new.bkp"
set "LOGPARSER_PATH=C:\LogParser\LogParser.exe"
set "DIRECTORIO_ORIGEN=\\server\audit\*.csv"
:: Crear timestamp limpio para el nombre del archivo
set "fecha=%date:~-4,4%%date:~-10,2%%date:~-7,2%"
set "hora=%time:~0,2%%time:~3,2%%time:~6,2%"
:: Limpiar espacios en la hora (puede haber espacios si es antes de las 10 AM)
set "hora=%hora: =0%"
set "ARCHIVO_LOG=C:\F\logparser_execution_%fecha%_%hora%.log"

echo =========================================
echo SCRIPT DE BACKUP Y LOGPARSER
echo =========================================
echo Inicio: %date% %time%
echo.

:: 1. GENERAR BACKUP
echo [1/4] Generando backup de %ARCHIVO_ORIGEN%...
if exist "%ARCHIVO_ORIGEN%" (
    if exist "%ARCHIVO_BACKUP%" (
        echo   - Eliminando backup anterior...
        del "%ARCHIVO_BACKUP%"
    )
    echo   - Creando backup...
    copy "%ARCHIVO_ORIGEN%" "%ARCHIVO_BACKUP%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   - Backup creado exitosamente: %ARCHIVO_BACKUP%
    ) else (
        echo   - ERROR: No se pudo crear el backup
        goto :error
    )
) else (
    echo   - ADVERTENCIA: Archivo origen no existe, continuando sin backup...
)

echo.

:: 2. MOSTRAR TAMAÑO DEL BACKUP
if exist "%ARCHIVO_BACKUP%" (
    for %%F in ("%ARCHIVO_BACKUP%") do (
        set "tamano_backup_bytes=%%~zF"
        call :ConvertirAMB !tamano_backup_bytes! tamano_backup_mb
        echo   - Tamaño del backup: !tamano_backup_mb! MB ^(!tamano_backup_bytes! bytes^)
    )
) else (
    set "tamano_backup_bytes=0"
    set "tamano_backup_mb=0.00"
    echo   - No hay backup previo (archivo nuevo)
)

echo.

:: 3. EJECUTAR LOGPARSER
echo [2/4] Ejecutando LogParser...
echo   - Comando: "%LOGPARSER_PATH%" "SELECT * INTO %ARCHIVO_ORIGEN% FROM %DIRECTORIO_ORIGEN% WHERE SensitivityLabel IS NOT NULL AND SensitivityLabel <> ''" -i:CSV -o:CSV
echo   - Procesando archivos de %DIRECTORIO_ORIGEN%...
echo.

:: Ejecutar LogParser y capturar la salida
"%LOGPARSER_PATH%" "SELECT * INTO %ARCHIVO_ORIGEN% FROM %DIRECTORIO_ORIGEN% WHERE SensitivityLabel IS NOT NULL AND SensitivityLabel <> ''" -i:CSV -o:CSV > temp_logparser_output.txt 2>&1

set "logparser_exit_code=%errorlevel%"

:: Mostrar output de LogParser
type temp_logparser_output.txt

echo.

:: 4. VERIFICAR RESULTADO Y MOSTRAR ESTADÍSTICAS
echo [3/4] Verificando resultado...
if %logparser_exit_code% equ 0 (
    echo   - LogParser ejecutado exitosamente
    
    :: Mostrar tamaño final del archivo
    if exist "%ARCHIVO_ORIGEN%" (
        for %%F in ("%ARCHIVO_ORIGEN%") do (
            set "tamano_final_bytes=%%~zF"
            call :ConvertirAMB !tamano_final_bytes! tamano_final_mb
            echo   - Tamaño final del archivo: !tamano_final_mb! MB ^(!tamano_final_bytes! bytes^)
            call :CalcularDiferencia !tamano_final_bytes! !tamano_backup_bytes! diferencia_mb diferencia_signo
            echo   - Diferencia respecto al backup: !diferencia_signo!!diferencia_mb! MB
        )
    ) else (
        echo   - ERROR: El archivo de salida no fue creado
        set "tamano_final_bytes=0"
        set "tamano_final_mb=0.00"
        goto :error
    )
) else (
    echo   - ERROR: LogParser falló con código de salida: %logparser_exit_code%
    goto :error
)

echo.

:: 5. GENERAR LOG DE ÉXITO
echo [4/4] Generando log de ejecución...
(
    echo =========================================
    echo LOG DE EJECUCIÓN - LOGPARSER BACKUP SCRIPT
    echo =========================================
    echo Fecha y hora de inicio: %date% %time%
    echo.
    echo CONFIGURACIÓN:
    echo - Archivo origen: %ARCHIVO_ORIGEN%
    echo - Archivo backup: %ARCHIVO_BACKUP%
    echo - Directorio fuente: %DIRECTORIO_ORIGEN%
    echo.
    echo ESTADÍSTICAS:
    echo - Tamaño del backup: !tamano_backup_mb! MB ^(!tamano_backup_bytes! bytes^)
    echo - Tamaño final: !tamano_final_mb! MB ^(!tamano_final_bytes! bytes^)
    echo - Diferencia respecto al backup: !diferencia_signo!!diferencia_mb! MB
    echo - Código de salida LogParser: %logparser_exit_code%
    echo.
    echo SALIDA DE LOGPARSER:
    type temp_logparser_output.txt
    echo.
    echo =========================================
    echo EJECUCIÓN COMPLETADA EXITOSAMENTE
    echo Fecha y hora de finalización: %date% %time%
    echo =========================================
) > "%ARCHIVO_LOG%"

echo   - Log generado: %ARCHIVO_LOG%
echo.
echo =========================================
echo PROCESO COMPLETADO EXITOSAMENTE
echo =========================================
goto :end

:error
echo.
echo =========================================
echo ERROR EN LA EJECUCIÓN
echo =========================================
(
    echo =========================================
    echo LOG DE EJECUCIÓN - ERROR
    echo =========================================
    echo Fecha y hora: %date% %time%
    echo.
    echo ERROR: El script no se ejecutó correctamente
    echo Código de salida LogParser: %logparser_exit_code%
    echo.
    echo SALIDA DE LOGPARSER:
    if exist temp_logparser_output.txt type temp_logparser_output.txt
    echo.
    echo =========================================
) > "%ARCHIVO_LOG%"
echo Log de error generado: %ARCHIVO_LOG%
exit /b 1

:end
:: Limpiar archivos temporales
if exist temp_logparser_output.txt del temp_logparser_output.txt

rem //OPCION DE EJECUTAR ALGUN COMANDO AL FINALIZAR//

echo.
echo Presiona cualquier tecla para salir...
pause >nul
exit /b 0

:: ==========================================
:: FUNCIONES AUXILIARES - SOLO BATCH
:: ==========================================

:ConvertirAMB
:: Convierte bytes a MB usando solo operaciones batch
:: Parámetros: %1=bytes, %2=variable_salida
setlocal enabledelayedexpansion
set "bytes=%~1"

:: Si es 0, retornar 0.00
if "%bytes%"=="0" (
    endlocal & set "%~2=0.00"
    goto :eof
)

:: Dividir por 1048576 (1024*1024) usando división entera
:: Para números grandes usamos truncamiento de strings

:: Primero obtener la parte entera (MB)
set /a "mb_entero=bytes / 1048576" 2>nul
if errorlevel 1 (
    :: Si hay overflow, usar método alternativo con strings
    call :DivisionGrande "%bytes%" mb_entero parte_decimal
) else (
    :: Calcular parte decimal
    set /a "resto=bytes %% 1048576"
    set /a "parte_decimal=(resto * 100) / 1048576"
)

:: Formatear con 2 decimales
if %parte_decimal% lss 10 set "parte_decimal=0%parte_decimal%"
set "resultado=%mb_entero%.%parte_decimal%"

endlocal & set "%~2=%resultado%"
goto :eof

:DivisionGrande
:: División para números muy grandes usando manipulación de strings
:: Parámetros: %1=numero, %2=variable_mb, %3=variable_decimal
setlocal enabledelayedexpansion
set "numero=%~1"
set "longitud=0"

:: Contar dígitos
:contar_loop
if defined numero (
    set "numero=!numero:~1!"
    set /a "longitud+=1"
    goto contar_loop
)

set "numero=%~1"

:: Para números de más de 7 dígitos, usar aproximación
if %longitud% gtr 7 (
    :: Aproximación: dividir por 1000000 y ajustar
    set "primeros_6=!numero:~0,6!"
    set /a "mb_aprox=primeros_6 / 1048"
    set "parte_decimal=00"
) else (
    :: Usar división normal
    set /a "mb_aprox=numero / 1048576"
    set /a "resto=numero %% 1048576"
    set /a "parte_decimal=(resto * 100) / 1048576"
)

endlocal & set "%~2=%mb_aprox%" & set "%~3=%parte_decimal%"
goto :eof

:CalcularDiferencia
:: Calcula diferencia entre dos tamaños usando solo batch
:: Parámetros: %1=tamaño1, %2=tamaño2, %3=variable_salida_mb, %4=variable_signo
setlocal enabledelayedexpansion
set "tam1=%~1"
set "tam2=%~2"

:: Comparar para determinar signo
call :CompararNumeros "%tam1%" "%tam2%" resultado_comparacion

if "%resultado_comparacion%"=="mayor" (
    set "signo=+"
    call :RestarGrandes "%tam1%" "%tam2%" diferencia_abs
) else if "%resultado_comparacion%"=="menor" (
    set "signo=-"
    call :RestarGrandes "%tam2%" "%tam1%" diferencia_abs
) else (
    set "signo="
    set "diferencia_abs=0"
)

:: Convertir diferencia a MB
call :ConvertirAMB !diferencia_abs! diferencia_mb

endlocal & set "%~3=%diferencia_mb%" & set "%~4=%signo%"
goto :eof

:CompararNumeros
:: Compara dos números grandes usando strings
:: Parámetros: %1=num1, %2=num2, %3=variable_resultado (mayor/menor/igual)
setlocal enabledelayedexpansion
set "num1=%~1"
set "num2=%~2"

:: Comparar longitudes primero
call :ContarDigitos "%num1%" len1
call :ContarDigitos "%num2%" len2

if %len1% gtr %len2% (
    endlocal & set "%~3=mayor"
    goto :eof
) else if %len1% lss %len2% (
    endlocal & set "%~3=menor"
    goto :eof
)

:: Misma longitud, comparar dígito por dígito
for /l %%i in (0,1,9) do (
    set "d1=!num1:~%%i,1!"
    set "d2=!num2:~%%i,1!"
    if "!d1!"=="" goto iguales
    if !d1! gtr !d2! (
        endlocal & set "%~3=mayor"
        goto :eof
    ) else if !d1! lss !d2! (
        endlocal & set "%~3=menor"
        goto :eof
    )
)

:iguales
endlocal & set "%~3=igual"
goto :eof

:ContarDigitos
:: Cuenta dígitos de un número
setlocal enabledelayedexpansion
set "numero=%~1"
set "contador=0"
:contar_digitos_loop
if defined numero (
    set "numero=!numero:~1!"
    set /a "contador+=1"
    goto contar_digitos_loop
)
endlocal & set "%~2=%contador%"
goto :eof

:RestarGrandes
:: Resta dos números grandes (asume num1 >= num2)
:: Para simplificar, usamos una aproximación básica
setlocal enabledelayedexpansion
set "num1=%~1"
set "num2=%~2"

:: Si los números son pequeños, usar resta normal
set /a "test1=num1" 2>nul
set /a "test2=num2" 2>nul
if not errorlevel 1 (
    set /a "resultado=num1-num2"
    endlocal & set "%~3=%resultado%"
    goto :eof
)

:: Para números muy grandes, aproximación simple
:: Tomar primeros 8 dígitos de cada uno
set "n1_corto=!num1:~0,8!"
set "n2_corto=!num2:~0,8!"
set /a "diff_aprox=n1_corto-n2_corto" 2>nul

:: Ajustar según la diferencia de longitudes
call :ContarDigitos "%num1%" len1
call :ContarDigitos "%num2%" len2
set /a "diff_len=len1-len2"

if %diff_len% gtr 0 set /a "diff_aprox*=10"

endlocal & set "%~3=%diff_aprox%"
goto :eof
