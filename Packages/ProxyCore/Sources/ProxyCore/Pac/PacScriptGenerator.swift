/// Genera el script de configuración automática de proxy (PAC).
public enum PacScriptGenerator {
    /// Todo el tráfico va al proxy salvo los nombres locales, que siguen siendo directos.
    /// Se ofrece primero el proxy HTTP porque lo admiten todos los clientes de PAC, incluidos los
    /// servicios de Windows y la autenticación de los navegadores; SOCKS5 queda como alternativa.
    public static func script(proxyHost: String, port: UInt16) -> String {
        """
        function FindProxyForURL(url, host) {
          if (isPlainHostName(host) || host === "localhost" || host === "127.0.0.1" || dnsDomainIs(host, ".local")) {
            return "DIRECT";
          }
          return "PROXY \(proxyHost):\(port); SOCKS5 \(proxyHost):\(port)";
        }

        """
    }

    /// URL del archivo PAC para una dirección de proxy dada.
    public static func url(proxyHost: String, port: UInt16) -> String {
        "http://\(proxyHost):\(port)\(PacHttpResponse.pacPath)"
    }
}
