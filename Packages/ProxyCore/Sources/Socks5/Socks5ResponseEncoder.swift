/// Construye los mensajes que el servidor envía al cliente.
public enum Socks5ResponseEncoder {
    /// Formato: VER(1) METHOD(1).
    public static func methodSelection(_ method: Socks5AuthMethod) -> [UInt8] {
        [Socks5Constants.version, method.rawValue]
    }

    /// Resultado de la autenticación usuario/contraseña. Formato: VER(1) STATUS(1).
    public static func authenticationStatus(succeeded: Bool) -> [UInt8] {
        [Socks5UserPassRequest.version, succeeded ? 0x00 : 0x01]
    }

    /// Formato: VER(1) REP(1) RSV(1) ATYP(1) BND.ADDR(4) BND.PORT(2).
    /// La dirección enlazada se informa como 0.0.0.0:0 porque los clientes CONNECT no la usan.
    public static func reply(_ code: Socks5ReplyCode) -> [UInt8] {
        [
            Socks5Constants.version,
            code.rawValue,
            Socks5Constants.reservedByte,
            Socks5AddressType.ipv4.rawValue,
            0, 0, 0, 0,
            0, 0,
        ]
    }
}
