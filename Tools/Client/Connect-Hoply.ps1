<#
.SYNOPSIS
    Conecta la laptop con Windows a Hoply en el iPhone.

.DESCRIPTION
    En modo USB inicia el reenvío de go-ios. Configura el proxy de Windows mientras el script
    esté activo: el automático (PAC), que leen los navegadores, y el manual, que leen muchas
    apps .NET, WinHTTP y de consola. Al salir con Ctrl+C restaura la configuración anterior.

.PARAMETER Mode
    Usb (por defecto) o WiFi.

.PARAMETER Port
    Puerto configurado en la app, entre 1024 y 65535. Por defecto, 1080.

.PARAMETER ProxyHost
    IP del iPhone que muestra la app. Obligatoria en modo WiFi.

.PARAMETER SkipSystemProxy
    No modifica el proxy de Windows; solo inicia el reenvío y verifica la conexión.

.EXAMPLE
    .\Connect-Hoply.ps1

.EXAMPLE
    .\Connect-Hoply.ps1 -Mode WiFi -ProxyHost 192.168.1.20
#>
[CmdletBinding()]
param(
    [ValidateSet('Usb', 'WiFi')]
    [string] $Mode = 'Usb',

    [ValidateRange(1024, 65535)]
    [int] $Port = 1080,

    [string] $ProxyHost,

    [switch] $SkipSystemProxy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VerifyUrl = 'https://ifconfig.me'
$ForwardStartupSeconds = 2
$InternetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$LocalAddresses = '<local>;localhost;127.0.0.1'
$ProxyValueNames = @('AutoConfigURL', 'ProxyEnable', 'ProxyServer', 'ProxyOverride')

function Test-IPv4Address {
    param([string] $Value)
    if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
    foreach ($octet in $Value.Split('.')) {
        if ([int] $octet -gt 255) { return $false }
    }
    return $true
}

function Update-InternetSettings {
    # Notifica a las aplicaciones que el proxy cambió, sin esperar a que lo relean.
    if (-not ('Hoply.WinInet' -as [type])) {
        Add-Type -Namespace Hoply -Name WinInet -MemberDefinition @'
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(System.IntPtr hInternet, int dwOption, System.IntPtr lpBuffer, int dwBufferLength);
'@
    }
    $settingsChanged = 39
    $refresh = 37
    [void] [Hoply.WinInet]::InternetSetOption([System.IntPtr]::Zero, $settingsChanged, [System.IntPtr]::Zero, 0)
    [void] [Hoply.WinInet]::InternetSetOption([System.IntPtr]::Zero, $refresh, [System.IntPtr]::Zero, 0)
}

function Get-ProxySettings {
    # Valores actuales; $null significa «no estaba definido» y se borra al restaurar.
    $current = Get-ItemProperty -Path $InternetSettingsPath -ErrorAction SilentlyContinue
    $values = @{}
    foreach ($name in $ProxyValueNames) {
        $property = if ($current) { $current.PSObject.Properties[$name] } else { $null }
        $values[$name] = if ($property) { $property.Value } else { $null }
    }
    return $values
}

function Set-ProxySettings {
    param([hashtable] $Values)
    foreach ($name in $ProxyValueNames) {
        $value = $Values[$name]
        if ($null -eq $value) {
            Remove-ItemProperty -Path $InternetSettingsPath -Name $name -ErrorAction SilentlyContinue
        } elseif ($name -eq 'ProxyEnable') {
            Set-ItemProperty -Path $InternetSettingsPath -Name $name -Value ([int] $value) -Type DWord
        } else {
            Set-ItemProperty -Path $InternetSettingsPath -Name $name -Value ([string] $value) -Type String
        }
    }
    Update-InternetSettings
}

function Start-UsbForward {
    # Solo ejecutables o .cmd: el intermediario .ps1 que crea npm no puede lanzarse con Start-Process.
    $ios = Get-Command ios -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ios) {
        throw 'No se encontró go-ios. Instálalo con: npm install -g go-ios'
    }
    $process = Start-Process -FilePath $ios.Source -ArgumentList @('forward', "$Port", "$Port") -PassThru -NoNewWindow
    Start-Sleep -Seconds $ForwardStartupSeconds
    if ($process.HasExited) {
        throw 'El reenvío USB terminó. Comprueba el cable, que Apple Devices esté instalado y que el iPhone confíe en esta laptop.'
    }
    return $process
}

function Test-ProxyConnection {
    param([string] $ProxyAddress)
    $address = & curl.exe --silent --show-error --max-time 15 --proxy "http://$ProxyAddress" $VerifyUrl 2>$null
    if ($LASTEXITCODE -eq 0 -and $address) {
        Write-Host "Conectado. IP pública a través del iPhone: $address"
    } else {
        Write-Warning 'No se pudo verificar la conexión. Comprueba que el proxy esté activo en la app.'
    }
}

if ($Mode -eq 'WiFi') {
    if (-not $ProxyHost -or -not (Test-IPv4Address $ProxyHost)) {
        throw 'En modo WiFi indica la IP del iPhone con -ProxyHost, por ejemplo -ProxyHost 192.168.1.20.'
    }
} else {
    $ProxyHost = '127.0.0.1'
}

$proxyAddress = "${ProxyHost}:$Port"
$pacUrl = "http://$proxyAddress/proxy.pac"
$previousProxySettings = Get-ProxySettings
$forwardProcess = $null
$systemProxyChanged = $false

try {
    if ($Mode -eq 'Usb') {
        $forwardProcess = Start-UsbForward
    }

    if (-not $SkipSystemProxy) {
        $systemProxyChanged = $true
        Set-ProxySettings @{
            AutoConfigURL = $pacUrl
            ProxyEnable   = 1
            ProxyServer   = $proxyAddress
            ProxyOverride = $LocalAddresses
        }
        Write-Host "Proxy automático de Windows configurado: $pacUrl"
        Write-Host "Proxy manual de Windows configurado: $proxyAddress"
    }

    Test-ProxyConnection -ProxyAddress $proxyAddress
    Write-Host "Proxy para herramientas de consola: http://$proxyAddress"
    Write-Host 'Pulsa Ctrl+C para desconectar y restaurar la configuración.'

    while ($true) {
        Start-Sleep -Seconds 1
        if ($forwardProcess -and $forwardProcess.HasExited) {
            Write-Warning 'El reenvío USB terminó.'
            break
        }
    }
} finally {
    if ($systemProxyChanged) {
        Set-ProxySettings $previousProxySettings
        Write-Host 'Configuración de proxy restaurada.'
    }
    if ($forwardProcess -and -not $forwardProcess.HasExited) {
        # go-ios instalado con npm se ejecuta a través de un intermediario; se detiene el árbol completo.
        & taskkill.exe /PID $forwardProcess.Id /T /F | Out-Null
    }
}
