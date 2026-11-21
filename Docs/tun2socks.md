# Túnel de sistema con tun2socks

El proxy de Hoply lo usan las aplicaciones que respetan la configuración de proxy del sistema: navegadores, `curl`, `git`, gestores de paquetes y la mayoría de herramientas de desarrollo. Algunas aplicaciones de escritorio y muchos clientes VPN la ignoran. Para ellas, [tun2socks](https://github.com/xjasonlyu/tun2socks) crea una interfaz de red virtual en la laptop y envía todo el tráfico TCP por el proxy SOCKS5 del iPhone.

Solo hace falta si alguna aplicación que necesitas no funciona con la configuración normal. Requiere permisos de administrador.

## Limitaciones

- **Solo TCP.** Hoply no reenvía UDP, porque el reenvío por USB de `ios forward` solo transporta TCP. En consecuencia:
  - **DNS:** las consultas DNS normales usan UDP y fallarán. Configura DNS cifrado (DNS over HTTPS o DNS over TLS), que viaja por TCP. Los pasos están en cada sistema.
  - **QUIC/HTTP3:** los navegadores vuelven a HTTP/2 por TCP automáticamente.
  - **VPN:** funcionan las que pueden ir por TCP, como OpenVPN en modo TCP o clientes SSL que recurren a TLS cuando no hay UDP. No funcionan WireGuard ni IPsec, que solo usan UDP.
  - **Videollamadas y juegos:** suelen preferir UDP; algunos recurren a TCP con peor calidad.
- **Bucle de rutas.** La guía de tun2socks advierte que un proxy local puede crear un bucle. Con Hoply no ocurre: en modo USB, `ios forward` habla con el iPhone a través de usbmuxd y no por la red IP; en modo Wi-Fi, la red local tiene una ruta más específica que las rutas del túnel.

## Preparación común

1. Inicia el proxy en el iPhone y, en modo USB, ejecuta `ios forward 1080 1080` en la laptop.
2. Descarga el binario de tun2socks de su página de [releases](https://github.com/xjasonlyu/tun2socks/releases) para tu sistema.
3. En los comandos, sustituye `127.0.0.1:1080` por la dirección que muestra la app si usas Wi-Fi u otro puerto.

## Windows

1. Descarga `wintun.dll` desde [wintun.net](https://www.wintun.net/) y colócalo junto a `tun2socks.exe`.
2. En una terminal de administrador, inicia el túnel y déjala abierta:

   ```powershell
   .\tun2socks.exe -device wintun -proxy socks5://127.0.0.1:1080
   ```

3. En otra terminal de administrador, configura la interfaz y la ruta:

   ```powershell
   netsh interface ipv4 set address name="wintun" source=static addr=192.168.123.1 mask=255.255.255.0
   netsh interface ipv4 set dnsservers name="wintun" static address=1.1.1.1 register=none validate=no
   netsh interface ipv4 add route 0.0.0.0/0 "wintun" 192.168.123.1 metric=1
   ```

4. DNS cifrado: en Configuración > Red e Internet > tu conexión > Asignación de servidor DNS, usa `1.1.1.1` con «DNS sobre HTTPS» activado.
5. Para deshacerlo, cierra tun2socks con Ctrl+C: la interfaz y su ruta desaparecen.

## macOS

1. Inicia el túnel y deja la terminal abierta:

   ```sh
   sudo ./tun2socks -device utun123 -proxy socks5://127.0.0.1:1080
   ```

2. En otra terminal, activa la interfaz y desvía el tráfico con dos rutas que cubren todo IPv4 sin reemplazar la ruta por defecto:

   ```sh
   sudo ifconfig utun123 198.18.0.1 198.18.0.1 up
   sudo route add -net 0.0.0.0/1 198.18.0.1
   sudo route add -net 128.0.0.0/1 198.18.0.1
   ```

3. DNS cifrado: instala un perfil de configuración de DNS sobre HTTPS (por ejemplo, el de tu proveedor de DNS preferido) o usa un cliente DoH local.
4. Para deshacerlo:

   ```sh
   sudo route delete -net 0.0.0.0/1 198.18.0.1
   sudo route delete -net 128.0.0.0/1 198.18.0.1
   ```

   y cierra tun2socks con Ctrl+C.

## Linux

1. Crea y activa la interfaz:

   ```sh
   sudo ip tuntap add mode tun dev tun0
   sudo ip addr add 198.18.0.1/15 dev tun0
   sudo ip link set dev tun0 up
   ```

2. Inicia el túnel y deja la terminal abierta:

   ```sh
   sudo ./tun2socks -device tun0 -proxy socks5://127.0.0.1:1080
   ```

3. En otra terminal, desvía el tráfico:

   ```sh
   sudo ip route add 0.0.0.0/1 dev tun0
   sudo ip route add 128.0.0.0/1 dev tun0
   ```

4. DNS cifrado con systemd-resolved: en `/etc/systemd/resolved.conf` define `DNS=1.1.1.1#cloudflare-dns.com` y `DNSOverTLS=yes`, y ejecuta `sudo systemctl restart systemd-resolved`.
5. Para deshacerlo: `sudo ip link delete tun0` (elimina también sus rutas) y cierra tun2socks.

## Comprobación

```sh
curl https://ifconfig.me
```

Sin indicar proxy, debe mostrar la IP de tu operador móvil.

Más detalles y opciones en la [wiki de tun2socks](https://github.com/xjasonlyu/tun2socks/wiki/Examples).
