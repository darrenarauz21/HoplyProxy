# Scripts para la laptop

Automatizan la conexión con Hoply: inician el reenvío USB, configuran el proxy automático del sistema mientras están activos, verifican la conexión y restauran todo al salir con Ctrl+C.

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
