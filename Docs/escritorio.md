# Hoply Desktop

App para la laptop que hace por ti la parte de la conexión: reenvía el puerto por USB, activa el proxy del sistema y lo deja como estaba al desconectar. Funciona en Windows, macOS y Linux.

## Descargar

Descarga el archivo de tu sistema desde la sección [Releases](../../../releases) del repositorio, o ejecuta el workflow **Build Desktop** en la pestaña **Actions** de tu fork.

| Sistema | Archivo |
| --- | --- |
| Windows | `Hoply-Desktop-win-x64.zip` |
| macOS con Apple Silicon | `Hoply-Desktop-osx-arm64.tar.gz` |
| macOS con Intel | `Hoply-Desktop-osx-x64.tar.gz` |
| Linux | `Hoply-Desktop-linux-x64.tar.gz` |

Dentro hay un único ejecutable, `Hoply`; no necesita instalar .NET.

- **macOS:** el ejecutable no está firmado. La primera vez, ábrelo con clic derecho > **Abrir**, o ejecuta `xattr -d com.apple.quarantine Hoply` en la carpeta donde lo guardaste.
- **Linux:** dale permiso de ejecución con `chmod +x Hoply`.

## Requisitos

| Sistema | Para USB | Proxy del sistema |
| --- | --- | --- |
| Windows | App **Apple Devices** (Microsoft Store) o iTunes | Sí |
| macOS | Nada adicional | Sí, en todos los servicios de red activos |
| Linux | Paquete `usbmuxd` (`sudo apt install usbmuxd`) | Sí, en escritorios GNOME, Cinnamon, Budgie y Unity |

En modo Wi-Fi no hace falta nada adicional en ningún sistema.

A diferencia de los scripts de `Tools/Client`, la app no necesita Node.js ni go-ios: habla directamente con el servicio de dispositivos de Apple (usbmuxd), el mismo que usan iTunes y Finder.

## Uso

1. En el iPhone, abre Hoply e inicia el proxy.
2. En la laptop, elige **USB** o **Wi-Fi**.
   - **USB:** conecta el cable. Si el iPhone pregunta, toca **Confiar**. La app muestra «iPhone conectado».
   - **Wi-Fi:** escribe la IP del iPhone, que aparece en la tarjeta **Conexión** de la app del iPhone.
3. Pulsa **Conectar**. Cuando todo funciona, la app muestra tu IP pública a través del iPhone.
4. Para terminar, pulsa **Desconectar** o sal de la app desde el icono de la bandeja del sistema. En ambos casos se restaura el proxy anterior.

### Bandeja del sistema

La app abre como un panel flotante en la esquina inferior derecha, junto al reloj. Al hacer clic fuera del panel, con la flecha del encabezado o con `Esc`, el panel se oculta pero la conexión sigue activa. Vuelve a abrirlo con un clic en el icono de Hoply de la bandeja; con el botón derecho tienes **Abrir Hoply** y **Salir**. **Salir** (o `Alt+F4`) cierra la app y restaura el proxy del sistema. En Windows 11 el icono puede aparecer en el cajón de iconos ocultos: arrástralo a la bandeja para tenerlo siempre a mano.

### Proxy del sistema

Con la opción **Proxy del sistema** activa, la app configura el proxy automático (archivo PAC) del sistema para que navegadores y apps salgan por el iPhone. Antes de cambiarlo guarda la configuración que tenías; al desconectar la restaura. Si la app se cierra de golpe, la restaura la próxima vez que la abras.

Desactívala si prefieres configurar cada app a mano.

### Terminal

**Copiar para la terminal** copia la línea que hace que `git`, `npm`, `curl` y otras herramientas usen el proxy en la terminal actual:

```sh
# macOS y Linux
export http_proxy=http://127.0.0.1:1080 https_proxy=http://127.0.0.1:1080 ALL_PROXY=socks5h://127.0.0.1:1080
```

```powershell
# Windows (PowerShell)
$env:HTTP_PROXY="http://127.0.0.1:1080"; $env:HTTPS_PROXY="http://127.0.0.1:1080"; $env:ALL_PROXY="socks5h://127.0.0.1:1080"
```

### Avanzado

El puerto debe ser el mismo que en **Ajustes** de la app del iPhone (por defecto, 1080). En USB es también el puerto local de la laptop.

## Solución de problemas

| Mensaje | Qué hacer |
| --- | --- |
| Instala la app Apple Devices o iTunes | Windows no tiene el servicio que reconoce el iPhone. Instálalo y vuelve a conectar el cable. |
| Conecta el iPhone y toca «Confiar» | Desbloquea el iPhone, reconecta el cable y acepta el aviso. Prueba otro cable o puerto si no aparece. |
| El puerto 1080 ya está en uso | Otro programa (por ejemplo, `ios forward` de go-ios) usa ese puerto. Ciérralo o cambia el puerto en ambas apps. |
| Conectado sin verificar | El proxy no está iniciado en el iPhone, la app del iPhone está en segundo plano o no hay datos móviles. |
| El iPhone no responde | Se desconectó el cable o se detuvo el proxy en el iPhone. |
| Revisa el proxy del sistema | No se pudo restaurar el proxy anterior. Ábrelo en la configuración de red del sistema y desactiva el proxy automático. |

## Arquitectura

```
Desktop/
  Hoply.Desktop.slnx
  src/Hoply.Desktop.Core/     sin interfaz
    Connection/                     opciones, validación y orquestación (PhoneConnection)
    Usbmux/                         cliente de usbmuxd y reenvío de puerto por USB
    SystemProxy/                    proxy automático en Windows, macOS y GNOME
    Storage/                        ajustes y recuperación del proxy anterior
    Verification/                   comprobación de la IP pública a través del proxy
  src/Hoply.Desktop/          interfaz Avalonia (MVVM)
    Views/, ViewModels/, Styles/, Localization/, Assets/
  tests/Hoply.Desktop.Tests/  pruebas de xUnit
```

Compilar y probar en local (requiere el SDK de .NET 10):

```sh
dotnet test Desktop/Hoply.Desktop.slnx
dotnet run --project Desktop/src/Hoply.Desktop
```

Los textos están en `Localization/` (`es.json`, `en.json`, `pt.json` y `fr.json`); la app usa el idioma del sistema y, si no lo tiene, el inglés.
