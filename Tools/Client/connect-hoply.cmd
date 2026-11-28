@echo off
rem Conecta la laptop con Windows a Hoply en el iPhone desde cmd, sin PowerShell.
rem Activa el proxy de Windows del usuario: el automatico (PAC), que leen los navegadores, y el
rem manual, que leen muchas apps .NET, WinHTTP y de consola. "off" deja la configuracion como estaba.
rem No inicia el reenvio USB: en modo USB debe estar abierto Hoply Desktop o "ios forward PUERTO PUERTO".
setlocal EnableExtensions EnableDelayedExpansion

for /f "tokens=2 delims=:." %%C in ('chcp') do set /a "PREVIOUS_CODEPAGE=%%C" 2>nul
chcp 65001 >nul

set "KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
set "VALUES=AutoConfigURL ProxyEnable ProxyServer ProxyOverride"
set "LOCAL_ADDRESSES=<local>;localhost;127.0.0.1"
set "BACKUP_DIR=%APPDATA%\Hoply"
set "BACKUP=%BACKUP_DIR%\connect-hoply-cmd.backup"
set "VERIFY_URL=https://ifconfig.me"
set "DEFAULT_HOST=127.0.0.1"
set "DEFAULT_PORT=1080"
set "EXIT_CODE=0"

set "ACTION=%~1"
if /i "%ACTION%"=="on" goto :on
if /i "%ACTION%"=="off" goto :off
if /i "%ACTION%"=="status" goto :status
call :usage
if not "%ACTION%"=="" set "EXIT_CODE=1"
goto :end

:usage
echo Uso: connect-hoply.cmd on [host] [puerto]
echo      connect-hoply.cmd off
echo      connect-hoply.cmd status [host] [puerto]
echo.
echo   on      Activa el proxy automático y el manual de Windows y comprueba la conexión.
echo   off     Restaura la configuración que había antes de "on".
echo   status  Muestra el proxy de Windows y comprueba la conexión.
echo   host    127.0.0.1 en USB (por defecto); la IP que muestra la app en Wi-Fi.
echo   puerto  El de Ajustes en la app del iPhone, 1024-65535 (por defecto, %DEFAULT_PORT%).
exit /b 0

:on
call :read_address "%~2" "%~3" || (set "EXIT_CODE=1" & goto :end)
set "PROXY=%HOST%:%PORT%"
if not exist "%BACKUP%" (
    call :save_backup || goto :fail
) else (
    echo Ya había una copia de la configuración anterior; se conserva.
)
reg add "%KEY%" /v AutoConfigURL /t REG_SZ /d "http://%PROXY%/proxy.pac" /f >nul || goto :fail
reg add "%KEY%" /v ProxyServer /t REG_SZ /d "%PROXY%" /f >nul || goto :fail
reg add "%KEY%" /v ProxyOverride /t REG_SZ /d "!LOCAL_ADDRESSES!" /f >nul || goto :fail
reg add "%KEY%" /v ProxyEnable /t REG_DWORD /d 1 /f >nul || goto :fail
call :notify
echo Proxy automático de Windows: http://%PROXY%/proxy.pac
echo Proxy manual de Windows:     %PROXY%
call :verify
echo Para desconectar: connect-hoply.cmd off
goto :end

:off
if not exist "%BACKUP%" (
    echo No hay copia de la configuración anterior. Se desactiva el proxy manual y se quita el automático.
    reg add "%KEY%" /v ProxyEnable /t REG_DWORD /d 0 /f >nul || goto :fail
    reg delete "%KEY%" /v AutoConfigURL /f >nul 2>&1
    call :notify
    goto :end
)
for /f "usebackq tokens=1,2,* delims=|" %%A in ("%BACKUP%") do (
    if "%%A"=="D" (
        reg delete "%KEY%" /v %%B /f >nul 2>&1
    ) else if "%%B"=="ProxyEnable" (
        reg add "%KEY%" /v %%B /t REG_DWORD /d %%C /f >nul || goto :fail
    ) else (
        reg add "%KEY%" /v %%B /t REG_SZ /d "%%C" /f >nul || goto :fail
    )
)
del "%BACKUP%" >nul 2>&1
call :notify
echo Configuración de proxy restaurada.
goto :end

:status
for %%V in (%VALUES%) do (
    call :read_value %%V
    if defined FOUND (echo %%V = !VALUE!) else (echo %%V = ^(no definido^))
)
if exist "%BACKUP%" (echo Copia de la configuración anterior: %BACKUP%) else (echo Sin copia pendiente.)
call :read_address "%~2" "%~3" || (set "EXIT_CODE=1" & goto :end)
set "PROXY=%HOST%:%PORT%"
call :verify
goto :end

rem Valida host y puerto; deja HOST y PORT.
:read_address
set "HOST=%~1"
set "PORT=%~2"
if "%HOST%"=="" set "HOST=%DEFAULT_HOST%"
if "%PORT%"=="" set "PORT=%DEFAULT_PORT%"
echo(%HOST%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul || (
    echo Error: el host debe ser una IP, por ejemplo 127.0.0.1 o 192.168.1.20. 1>&2
    exit /b 1
)
for /f "tokens=1-4 delims=." %%A in ("%HOST%") do (
    for %%O in (%%A %%B %%C %%D) do if %%O gtr 255 (
        echo Error: el host debe ser una IP válida. 1>&2
        exit /b 1
    )
)
echo(%PORT%| findstr /r "^[0-9][0-9]*$" >nul || goto :invalid_port
if %PORT% lss 1024 goto :invalid_port
if %PORT% gtr 65535 goto :invalid_port
exit /b 0

:invalid_port
echo Error: el puerto debe estar entre 1024 y 65535. 1>&2
exit /b 1

rem Lee un valor de la clave; deja FOUND (definido si existe) y VALUE.
:read_value
set "FOUND="
set "VALUE="
for /f "tokens=1,2,*" %%A in ('reg query "%KEY%" /v %1 2^>nul ^| findstr /b /c:"    %1 "') do (
    set "FOUND=1"
    if /i "%%B"=="REG_DWORD" (set /a "VALUE=%%C") else (set "VALUE=%%C")
)
exit /b 0

rem Guarda los cuatro valores: S|nombre|valor si existía, D|nombre| si hay que borrarlo al restaurar.
:save_backup
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" || exit /b 1
type nul > "%BACKUP%" || exit /b 1
for %%V in (%VALUES%) do (
    call :read_value %%V
    if defined FOUND (>>"%BACKUP%" echo S^|%%V^|!VALUE!) else (>>"%BACKUP%" echo D^|%%V^|)
)
exit /b 0

rem Avisa a las apps abiertas del cambio (InternetSetOption 39 y 37). Si PowerShell no está, lo verán al releer.
:notify
powershell -NoProfile -NonInteractive -Command "$s='[DllImport(\"wininet.dll\")] public static extern bool InternetSetOption(System.IntPtr h, int o, System.IntPtr b, int l);'; $t=Add-Type -Name WinInet -Namespace HoplyCmd -MemberDefinition $s -PassThru; [void]$t::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0); [void]$t::InternetSetOption([IntPtr]::Zero,37,[IntPtr]::Zero,0)" >nul 2>&1
exit /b 0

:verify
where curl.exe >nul 2>&1 || (
    echo No se encontró curl.exe para comprobar la conexión.
    exit /b 0
)
set "ADDRESS="
for /f "delims=" %%A in ('curl.exe --silent --show-error --max-time 15 --proxy "http://%PROXY%" "%VERIFY_URL%" 2^>nul') do set "ADDRESS=%%A"
if defined ADDRESS (
    echo Conectado. IP pública a través del iPhone: !ADDRESS!
) else (
    echo No se pudo verificar la conexión por %PROXY%. Comprueba que el proxy esté iniciado en la app y que el puerto sea el mismo. 1>&2
    set "EXIT_CODE=2"
)
exit /b 0

:fail
echo Error: no se pudo completar la operación. 1>&2
set "EXIT_CODE=1"

:end
if defined PREVIOUS_CODEPAGE chcp %PREVIOUS_CODEPAGE% >nul
endlocal & exit /b %EXIT_CODE%
