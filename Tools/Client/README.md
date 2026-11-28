# Scripts para la laptop

Automatizan la conexión con Hoply: inician el reenvío USB, configuran el proxy automático del sistema mientras están activos, verifican la conexión y restauran todo al salir con Ctrl+C. En Windows activan además el proxy manual (`ProxyEnable`, `ProxyServer` y `ProxyOverride`), que leen muchas apps .NET, WinHTTP y de consola que ignoran el PAC.

Requisitos: el proxy iniciado en la app y, en modo USB, [go-ios](https://github.com/danielpaulus/go-ios) instalado (`npm install -g go-ios`).

## Windows (PowerShell)

```powershell
# USB, puerto 1080
.\Connect-Hoply.ps1

# Wi-Fi, con la IP que muestra la app
.\Connect-Hoply.ps1 -Mode WiFi -ProxyHost 192.168.1.20

# Sin tocar el proxy de Windows
.\Connect-Hoply.ps1 -SkipSystemProxy
```

Si PowerShell bloquea el script, ejecútalo con `powershell -ExecutionPolicy Bypass -File .\Connect-Hoply.ps1`.

## Windows (cmd)

`connect-hoply.cmd` activa y desactiva el proxy de Windows (automático y manual) sin quedarse abierto. No inicia el reenvío USB: en modo USB debe estar conectado Hoply Desktop o corriendo `ios forward PUERTO PUERTO`.

```bat
:: USB, puerto 1080
connect-hoply.cmd on

:: Otro puerto, o Wi-Fi con la IP que muestra la app
connect-hoply.cmd on 127.0.0.1 1180
connect-hoply.cmd on 192.168.1.20 1180

:: Ver el proxy de Windows y comprobar la conexión con curl.exe
connect-hoply.cmd status 127.0.0.1 1180

:: Restaurar la configuración anterior
connect-hoply.cmd off
```

`on` guarda la configuración anterior en `%APPDATA%\Hoply\connect-hoply-cmd.backup` y `off` la restaura; los valores que no existían se borran.

## macOS y Linux

```sh
# USB, solo reenvío y verificación
./connect-hoply.sh

# USB y proxy automático del sistema (macOS: servicio Wi-Fi; Linux: GNOME)
./connect-hoply.sh --system-proxy

# macOS con otro servicio de red
./connect-hoply.sh --system-proxy --service "USB 10/100/1000 LAN"

# Wi-Fi
./connect-hoply.sh --mode wifi --host 192.168.1.20 --system-proxy
```

El script muestra la línea `export` para usar el proxy en otras terminales.

Para aplicaciones que ignoran el proxy del sistema, consulta [la guía de tun2socks](../../Docs/tun2socks.md).
