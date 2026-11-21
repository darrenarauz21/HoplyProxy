# Documentación técnica

## Visión general

```
USB:   Laptop --go-ios--> iPhone 127.0.0.1:1080 --> salida por datos móviles --> Internet
Wi-Fi: Laptop --red local--> iPhone <IP Wi-Fi>:1080 --> salida por datos móviles --> Internet
```

Un único puerto atiende SOCKS5, proxy HTTP (`CONNECT` para HTTPS y URL absolutas para HTTP) y el archivo PAC en `/proxy.pac`. El protocolo se detecta por el primer byte de cada conexión.

## Capas

| Capa | Tipo | Responsabilidad |
| --- | --- | --- |
| Transporte de entrada | `InboundTransport`, `NetworkListenerTransport` | Escucha en 127.0.0.1 (USB) o solo en la interfaz Wi-Fi, nunca en la celular |
| Control de acceso | `ClientAccessPolicy`, `CredentialVerifier` | Lista de clientes autorizados en Wi-Fi y verificación de credenciales en tiempo constante |
| Protocolo | módulo `Socks5`, carpeta `Http` | SOCKS5 (RFC 1928 y 1929) y HTTP: túnel `CONNECT`, reenvío de URL absolutas con autenticación Basic y archivo PAC |
| Salida | `OutboundConnector`, `NetworkOutboundConnector` | Abre el destino forzando la interfaz celular; el DNS se resuelve en el iPhone |
| Relevo | `BidirectionalRelay` | Copia bytes en ambos sentidos con contrapresión, half-close y cierre por inactividad |
| Orquestación | `ProxyServer`, `ConnectionSession` | Ciclo de vida, límite de conexiones y estado observable |
| Actividad | `ProxyActivityRecorder` | Contadores de tráfico y sucesos de diagnóstico sin destinos |
| Configuración | paquete `ProxyConfig` | Ajustes, validación, persistencia, Keychain, guía por sistema operativo y caducidad de la firma |

La app (SwiftUI) solo depende de los paquetes a través de `ProxyController`, que coordina el servidor, el monitor de red, el modo en segundo plano y el recordatorio de renovación.

## Estructura

```
App/
  Sources/
    HoplyApp.swift, AppContainer.swift   punto de entrada y composición
    Core/                                      controlador, actividad y firma
    DesignSystem/                              tema, tarjetas, botones y componentes visuales
    Features/                                  pantallas: Root, Home, Setup, Guide, Docs, Settings, Activity
    Presentation/                              textos y colores de los modelos
    Components/                                vistas reutilizables
    Services/                                  red, pantalla, audio en segundo plano y notificaciones
  Resources/                                   textos en español, inglés, portugués y francés e ícono
Packages/ProxyCore/                            servidor, protocolos, acceso y PAC (sin interfaz)
Packages/ProxyConfig/                          ajustes, validación, Keychain, guía y firma (sin interfaz)
Desktop/                                       Hoply Desktop (Avalonia), ver Docs/escritorio.md
Tools/Client/                                  scripts de conexión para la laptop
Tools/Icon/                                    generador del ícono de iPhone y escritorio
Docs/                                          documentación
project.yml                                    definición del proyecto para XcodeGen
.github/workflows/build-ipa.yml                pruebas y compilación del IPA
.github/workflows/build-desktop.yml            pruebas y compilación de la app de escritorio
.github/workflows/release.yml                  publica ambas en Releases al subir una etiqueta vX.Y.Z
```

## Compilar

El workflow **Build IPA** se ejecuta manualmente desde la pestaña **Actions**. Primero ejecuta las pruebas de `ProxyCore` y `ProxyConfig` y después genera el proyecto con XcodeGen y compila un IPA sin firmar, que se publica como artefacto `Hoply-ipa`. La firma la aplica Sideloadly o AltStore al instalar.

Para publicar una versión, sube `MARKETING_VERSION` en `project.yml` (y `Version` en `Desktop/Directory.Build.props`) y fusiona en `main`. El workflow **Release** compila el IPA y la app de escritorio para Windows, macOS y Linux, crea la etiqueta `vX.Y.Z` y adjunta todo a una release nueva. En las ramas `release/**` solo compila, para validar antes de fusionar.

El ícono se genera con `python3 Tools/Icon/generate_icon.py` (requiere Pillow) a partir de una cuadrícula de píxeles.

Con una Mac y Xcode 16 o posterior:

```sh
brew install xcodegen
xcodegen generate
open Hoply.xcodeproj
```

Para ejecutar las pruebas de los paquetes:

```sh
(cd Packages/ProxyCore && swift test)
(cd Packages/ProxyConfig && swift test)
```

## Textos

Todos los textos visibles están en `App/Resources/Localizable.xcstrings` (español, inglés, portugués de Brasil y francés) y los de permisos en `InfoPlist.xcstrings`. Las vistas usan claves, nunca texto literal.
